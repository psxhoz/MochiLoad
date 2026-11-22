//
//  MochiSelfUpdater.swift
//  MochiLoad
//
//  Finds new MochiLoad versions in the MochiLoad source and installs them with one tap
//  (or by itself when the app is opened). iOS closes MochiLoad while it replaces itself,
//  so a notification tells the person when it's ready to open again.
//

import UIKit
import UserNotifications
import CoreData

@MainActor
final class MochiSelfUpdater: ObservableObject
{
    static let shared = MochiSelfUpdater()

    static let autoUpdateKey = "mochi.autoUpdateOnOpen"

    /// Install new MochiLoad versions by itself when the app is opened. On by default.
    static var autoUpdateOnOpen: Bool {
        get { UserDefaults.standard.object(forKey: autoUpdateKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoUpdateKey) }
    }

    /// Newer version in the source, if any.
    @Published private(set) var availableVersion: String?
    @Published private(set) var isUpdating = false
    @Published private(set) var progress: Double = 0

    private var lastSourceCheck: Date?
    private var lastAutoAttempt: (version: String, date: Date)?
    private var progressObservation: NSKeyValueObservation?
    private var didScheduleReopenNotification = false

    private static let reopenNotificationID = "mochi.selfUpdate.reopen"

    private init() {}

    // MARK: - Checking

    /// Reads the update state from the database (cheap).
    func reloadAvailableVersion()
    {
        guard DatabaseManager.shared.isStarted else { return }
        let context = DatabaseManager.shared.viewContext
        if let app = InstalledApp.fetchAltStore(in: context), app.hasUpdate
        {
            self.availableVersion = app.storeApp?.latestSupportedVersion?.version
        }
        else
        {
            self.availableVersion = nil
        }
    }

    /// Downloads the source list again (at most every 10 minutes unless forced), then reloads.
    func checkForUpdate(force: Bool = false) async
    {
        guard DatabaseManager.shared.isStarted else { return }
        if !force, let last = self.lastSourceCheck, Date().timeIntervalSince(last) < 10 * 60
        {
            self.reloadAvailableVersion()
            return
        }
        self.lastSourceCheck = Date()

        do
        {
            let (_, context) = try await AppManager.shared.fetchSources()
            try await context.performAsync { try context.save() }
        }
        catch let error as AppManager.FetchSourcesError
        {
            // Some sources failed; save the ones that worked.
            if let context = error.managedObjectContext
            {
                try? await context.performAsync { try context.save() }
            }
            debugLog("[MochiSelfUpdater] Some sources failed to load: \(error)")
        }
        catch
        {
            debugLog("[MochiSelfUpdater] Could not check for updates: \(error)")
        }

        self.reloadAvailableVersion()
    }

    // MARK: - Updating

    /// Called when MochiLoad opens. Returns true if an update started (so nothing else should run).
    func autoUpdateIfNeeded(presentingViewController: UIViewController) async -> Bool
    {
        guard Self.autoUpdateOnOpen, !self.isUpdating else { return false }
        guard PairingFileManager.shared.fetchPairingFile() != nil else { return false }

        await self.checkForUpdate()
        guard let version = self.availableVersion else { return false }

        // Don't keep retrying the same version every time the app opens if it failed.
        if let last = self.lastAutoAttempt, last.version == version, Date().timeIntervalSince(last.date) < 6 * 60 * 60
        {
            return false
        }

        do
        {
            try await ensureMinimuxerReady()
        }
        catch
        {
            debugLog("[MochiSelfUpdater] Not connected; leaving the update for later.")
            return false
        }

        self.lastAutoAttempt = (version, Date())
        return self.startUpdate(presentingViewController: presentingViewController, automatic: true)
    }

    /// Starts the update. Shows friendly messages for every outcome.
    @discardableResult
    func startUpdate(presentingViewController: UIViewController, automatic: Bool = false) -> Bool
    {
        guard !self.isUpdating else { return true }
        guard DatabaseManager.shared.isStarted,
              let installedApp = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext),
              installedApp.hasUpdate
        else {
            if !automatic
            {
                ToastView(text: NSLocalizedString("MochiLoad is up to date", comment: ""), detailText: nil).show(in: presentingViewController)
            }
            self.reloadAvailableVersion()
            return false
        }

        let version = installedApp.storeApp?.latestSupportedVersion?.version ?? ""

        if !automatic
        {
            // A manual tap: make sure we can reach the iPhone first, with a clear message if not.
            Task { @MainActor in
                do
                {
                    try await ensureMinimuxerReady()
                    self.performUpdate(installedApp, version: version, presentingViewController: presentingViewController, automatic: false)
                }
                catch
                {
                    ToastView(text: NSLocalizedString("Turn on LocalDevVPN first", comment: ""),
                              detailText: NSLocalizedString("Open LocalDevVPN, tap Connect, then tap Update again.", comment: "")).show(in: presentingViewController)
                }
            }
            return true
        }

        self.performUpdate(installedApp, version: version, presentingViewController: presentingViewController, automatic: true)
        return true
    }

    private func performUpdate(_ installedApp: InstalledApp, version: String, presentingViewController: UIViewController, automatic: Bool)
    {
        guard !self.isUpdating else { return }
        self.isUpdating = true
        self.progress = 0
        self.didScheduleReopenNotification = false

        let title = automatic
            ? String(format: NSLocalizedString("Updating MochiLoad to %@", comment: ""), version)
            : NSLocalizedString("Updating MochiLoad…", comment: "")
        ToastView(text: title,
                  detailText: NSLocalizedString("It closes by itself when it's done. You'll get a notification to open it again.", comment: ""))
            .show(in: presentingViewController.view, duration: 5)

        let progress = AppManager.shared.update(installedApp, presentingViewController: presentingViewController) { [weak self] result in
            DispatchQueue.main.async {
                self?.updateFinished(result, presentingViewController: presentingViewController)
            }
        }

        self.progressObservation = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            DispatchQueue.main.async {
                guard let self else { return }
                self.progress = fraction
                // The install step is near the end. iOS may close MochiLoad any moment after this,
                // so leave a notification behind that says it's ready.
                if fraction >= 0.8 && !self.didScheduleReopenNotification
                {
                    self.didScheduleReopenNotification = true
                    Self.scheduleReopenNotification(version: version)
                }
            }
        }
    }

    private func updateFinished(_ result: Result<InstalledApp, Error>, presentingViewController: UIViewController)
    {
        self.progressObservation?.invalidate()
        self.progressObservation = nil
        self.isUpdating = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reopenNotificationID])

        switch result
        {
        case .success:
            self.progress = 1
            ToastView(text: NSLocalizedString("MochiLoad updated", comment: ""), detailText: nil).show(in: presentingViewController)

        case .failure(let error) where error is CancellationError:
            break

        case .failure(let error):
            ToastView(error: error, opensLog: true).show(in: presentingViewController)
        }

        self.reloadAvailableVersion()
    }

    private static func scheduleReopenNotification(version: String)
    {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("MochiLoad is updated", comment: "")
        content.body = version.isEmpty
            ? NSLocalizedString("Tap to open it again.", comment: "")
            : String(format: NSLocalizedString("Version %@ is ready. Tap to open it again.", comment: ""), version)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 12, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: reopenNotificationID, content: content, trigger: trigger))
    }

    /// Clears the "ready" notification if MochiLoad is open again.
    static func appDidOpen()
    {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reopenNotificationID])
    }
}

//
//  MochiRefreshLiveActivity.swift
//  MochiLoad
//
//  Shows refresh progress on the lock screen / Dynamic Island while apps refresh.
//  Follows a RefreshGroup's Progress and ends with a short summary.
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

final class MochiRefreshLiveActivity: NSObject
{
    static let enabledKey = "mochi.refreshLiveActivity"

    /// On by default.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var observation: NSKeyValueObservation?
    private var lastSentProgress: Double = -1
    private let appCount: Int
    private let firstAppName: String?
    private var activityBox: Any?

    /// Starts following `progress`. Returns nil if Live Activities are off or unavailable.
    static func start(appNames: [String], progress: Progress) -> MochiRefreshLiveActivity?
    {
        guard self.isEnabled, !appNames.isEmpty else { return nil }

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let controller = MochiRefreshLiveActivity(appCount: appNames.count, firstAppName: appNames.count == 1 ? appNames.first : nil)
        let state = MochiRefreshAttributes.ContentState(progress: 0, title: controller.runningTitle, detail: NSLocalizedString("Keep LocalDevVPN on until it's done.", comment: ""))

        do
        {
            let activity = try Activity.request(attributes: MochiRefreshAttributes(appCount: appNames.count),
                                                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)),
                                                pushType: nil)
            controller.activityBox = activity
        }
        catch
        {
            debugLog("[MochiRefreshLiveActivity] Could not start: \(error)")
            return nil
        }

        controller.observation = progress.observe(\.fractionCompleted, options: [.new]) { [weak controller] progress, _ in
            controller?.progressChanged(progress.fractionCompleted)
        }
        return controller
        #else
        return nil
        #endif
    }

    private init(appCount: Int, firstAppName: String?)
    {
        self.appCount = appCount
        self.firstAppName = firstAppName
        super.init()
    }

    private var runningTitle: String {
        if let name = self.firstAppName { return String(format: NSLocalizedString("Refreshing %@", comment: ""), name) }
        return String(format: NSLocalizedString("Refreshing %d apps", comment: ""), self.appCount)
    }

    private func progressChanged(_ fraction: Double)
    {
        // Live Activities have an update budget; only send noticeable changes.
        guard fraction - self.lastSentProgress >= 0.05 || fraction >= 1 else { return }
        self.lastSentProgress = fraction

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let activity = self.activityBox as? Activity<MochiRefreshAttributes> else { return }
        let state = MochiRefreshAttributes.ContentState(progress: min(fraction, 0.99), title: self.runningTitle,
                                                        detail: NSLocalizedString("Signing your apps again…", comment: ""))
        Task { await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))) }
        #endif
    }

    /// Shows the result for a few seconds, then removes the Live Activity.
    func finish(failedCount: Int)
    {
        self.observation?.invalidate()
        self.observation = nil

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let activity = self.activityBox as? Activity<MochiRefreshAttributes> else { return }

        let state: MochiRefreshAttributes.ContentState
        if failedCount == 0
        {
            let title = self.appCount == 1 ? NSLocalizedString("App refreshed", comment: "") : NSLocalizedString("All apps refreshed", comment: "")
            state = .init(progress: 1, title: title, detail: NSLocalizedString("Good for another 7 days.", comment: ""), isFinished: true)
        }
        else
        {
            let title = failedCount == 1 ? NSLocalizedString("1 app didn't refresh", comment: "") : String(format: NSLocalizedString("%d apps didn't refresh", comment: ""), failedCount)
            state = .init(progress: 1, title: title, detail: NSLocalizedString("Open MochiLoad to see why.", comment: ""), isFinished: true, didFail: true)
        }

        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(8)))
        }
        #endif
    }
}

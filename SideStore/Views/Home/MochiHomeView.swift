//
//  MochiHomeView.swift
//  MochiLoad
//
//  The first tab: is everything set up, when does the next app expire, one big Refresh button,
//  and plain-English answers underneath. Made for people who have never sideloaded before.
//

import SwiftUI
import UIKit
import CoreData

extension Notification.Name
{
    /// Home asks the tab bar to refresh every app (shows progress in My Apps).
    static let mochiRefreshAllApps = Notification.Name("mochi.refreshAllApps")
    /// Home asks the tab bar to open the pairing screen.
    static let mochiOpenPairing = Notification.Name("mochi.openPairing")
    /// Home asks the tab bar to switch to Settings (to sign in).
    static let mochiOpenSettings = Notification.Name("mochi.openSettings")
    /// Home asks the tab bar to switch to My Apps (to update MochiLoad).
    static let mochiOpenMyApps = Notification.Name("mochi.openMyApps")
    /// Home asks the tab bar to install the new MochiLoad version.
    static let mochiUpdateMochiLoad = Notification.Name("mochi.updateMochiLoad")
}

enum MochiAutomation
{
    static let autoRefreshOnOpenKey = "mochi.autoRefreshOnOpen"

    /// Refresh apps that expire within 2 days whenever MochiLoad is opened. On by default.
    static var autoRefreshOnOpen: Bool {
        get { UserDefaults.standard.object(forKey: autoRefreshOnOpenKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoRefreshOnOpenKey) }
    }
}

struct MochiHomeApp: Identifiable
{
    let id: String
    let name: String
    let refreshedDate: Date
    let expirationDate: Date

    var secondsLeft: TimeInterval { self.expirationDate.timeIntervalSinceNow }

    /// 1 = just refreshed, 0 = expired.
    var fractionLeft: Double {
        let total = self.expirationDate.timeIntervalSince(self.refreshedDate)
        guard total > 0 else { return 0 }
        return min(max(self.secondsLeft / total, 0), 1)
    }

    var color: Color {
        switch self.secondsLeft
        {
        case ..<(60 * 60 * 24): return Color(hex: 0xF87171)
        case ..<(60 * 60 * 24 * 3): return MochiColors.warning
        default: return Color(hex: 0x5EEAD4)
        }
    }

    var timeLeftText: String {
        let seconds = self.secondsLeft
        if seconds <= 0 { return NSLocalizedString("Expired", comment: "") }
        let days = Int(seconds / 86400)
        if days >= 1
        {
            return days == 1 ? NSLocalizedString("1 day left", comment: "") : String(format: NSLocalizedString("%d days left", comment: ""), days)
        }
        let hours = max(Int(seconds / 3600), 1)
        return hours == 1 ? NSLocalizedString("1 hour left", comment: "") : String(format: NSLocalizedString("%d hours left", comment: ""), hours)
    }
}

@MainActor
final class MochiHomeViewModel: ObservableObject
{
    @Published var accountName: String?
    @Published var isPaired = false
    /// nil while checking.
    @Published var isConnected: Bool?
    @Published var apps: [MochiHomeApp] = []
    /// App icons by bundle ID, loaded once.
    @Published var icons: [String: UIImage] = [:]

    private var connectionTask: Task<Void, Never>?

    func reload()
    {
        self.isPaired = PairingFileManager.shared.fetchPairingFile() != nil

        if DatabaseManager.shared.isStarted
        {
            let context = DatabaseManager.shared.viewContext
            if let account = DatabaseManager.shared.activeAccount(in: context)
            {
                self.accountName = account.firstName.isEmpty ? account.appleID : account.firstName
            }
            else
            {
                self.accountName = nil
            }

            MochiSelfUpdater.shared.reloadAvailableVersion()

            let installedApps = InstalledApp.fetchActiveApps(in: context)
            self.apps = installedApps
                .map { MochiHomeApp(id: $0.bundleIdentifier, name: $0.name, refreshedDate: $0.refreshedDate, expirationDate: $0.expirationDate) }
                .sorted { $0.expirationDate < $1.expirationDate }

            for installedApp in installedApps where self.icons[installedApp.bundleIdentifier] == nil
            {
                let bundleID = installedApp.bundleIdentifier
                Task { [weak self] in
                    if let icon = try? await installedApp.loadIcon()
                    {
                        self?.icons[bundleID] = icon
                    }
                }
            }
        }

        self.connectionTask?.cancel()
        guard self.isPaired else {
            self.isConnected = false
            return
        }
        self.connectionTask = Task { [weak self] in
            do
            {
                try await ensureMinimuxerReady()
                if !Task.isCancelled { self?.isConnected = true }
            }
            catch
            {
                if !Task.isCancelled { self?.isConnected = false }
            }
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour
        {
        case 5..<12: base = NSLocalizedString("Good morning", comment: "")
        case 12..<18: base = NSLocalizedString("Good afternoon", comment: "")
        default: base = NSLocalizedString("Good evening", comment: "")
        }
        if let name = self.accountName, !name.contains("@") { return base + ", " + name }
        return base
    }

    var isReady: Bool { self.accountName != nil && self.isPaired && self.isConnected == true }
}

struct MochiHomeView: View
{
    @StateObject private var model = MochiHomeViewModel()
    @ObservedObject private var updater = MochiSelfUpdater.shared
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            MochiAuroraBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(self.model.greeting)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(MochiColors.mutedText)
                        .padding(.top, 4)

                    if let version = self.updater.availableVersion
                    {
                        self.updateCard(version: version)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    self.heroCard

                    Text(NSLocalizedString("Setup", comment: "")).mochiSectionLabel()
                    self.setupCard

                    if !self.model.apps.isEmpty
                    {
                        Text(NSLocalizedString("Your apps", comment: "")).mochiSectionLabel()
                        self.appsCard
                    }

                    Text(NSLocalizedString("Quick answers", comment: "")).mochiSectionLabel()
                    MochiLearnCards()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(NSLocalizedString("Home", comment: ""))
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: self.updater.availableVersion)
        .onAppear {
            self.model.reload()
            Task { await self.updater.checkForUpdate() }
        }
        .onReceive(self.timer) { _ in self.model.reload() }
        .onChange(of: self.scenePhase) { phase in
            if phase == .active { self.model.reload() }
        }
    }

    // MARK: - Hero

    private var heroCard: some View
    {
        let next = self.model.apps.first

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: next?.fractionLeft ?? (self.model.isReady ? 1 : 0))
                        .stroke(next?.color ?? Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: next?.fractionLeft)
                    Image(systemName: self.heroSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(next?.color ?? Color.accentColor)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 4) {
                    Text(self.heroTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(MochiColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(self.heroSubtitle)
                        .font(.subheadline)
                        .foregroundColor(MochiColors.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !self.model.apps.isEmpty
            {
                SwiftUI.Button {
                    NotificationCenter.default.post(name: .mochiRefreshAllApps, object: nil)
                } label: {
                    Label(NSLocalizedString("Refresh All Apps", comment: ""), systemImage: "arrow.clockwise")
                }
                .buttonStyle(MochiPrimaryButtonStyle(isEnabled: self.model.isConnected == true))
                .disabled(self.model.isConnected != true)

                if self.model.isConnected != true
                {
                    Text(NSLocalizedString("Turn on LocalDevVPN first, then come back here.", comment: ""))
                        .font(.footnote)
                        .foregroundColor(MochiColors.warning)
                }
            }
        }
        .padding(20)
        .mochiGlass(cornerRadius: 26)
    }

    private var heroSymbol: String {
        guard let next = self.model.apps.first else { return self.model.isReady ? "checkmark" : "sparkles" }
        return next.secondsLeft < 60 * 60 * 24 * 2 ? "exclamationmark" : "checkmark"
    }

    private var heroTitle: String {
        guard let next = self.model.apps.first else {
            return self.model.isReady ? NSLocalizedString("You're all set", comment: "") : NSLocalizedString("Let's get you set up", comment: "")
        }
        if next.secondsLeft <= 0 { return NSLocalizedString("Refresh needed", comment: "") }
        if next.secondsLeft < 60 * 60 * 24 * 2 { return NSLocalizedString("Refresh soon", comment: "") }
        return NSLocalizedString("All apps are working", comment: "")
    }

    private var heroSubtitle: String {
        guard let next = self.model.apps.first else {
            return self.model.isReady
                ? NSLocalizedString("Install apps from Browse, or open an IPA file.", comment: "")
                : NSLocalizedString("Finish the steps below. It only takes a few minutes.", comment: "")
        }
        if next.secondsLeft <= 0
        {
            return String(format: NSLocalizedString("%@ stopped opening. Tap Refresh All Apps to fix it.", comment: ""), next.name)
        }
        return String(format: NSLocalizedString("%@ expires first: %@.", comment: ""), next.name, next.timeLeftText.lowercased())
    }

    // MARK: - Update

    private func updateCard(version: String) -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: self.updater.isUpdating ? "arrow.down.circle" : "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.18)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.updater.isUpdating
                         ? NSLocalizedString("Updating MochiLoad…", comment: "")
                         : NSLocalizedString("MochiLoad update ready", comment: ""))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(MochiColors.text)
                    Text(self.updater.isUpdating
                         ? NSLocalizedString("It closes by itself when done. Open it again from the notification.", comment: "")
                         : String(format: NSLocalizedString("Version %@. Your apps and sign-in stay.", comment: ""), version))
                        .font(.footnote)
                        .foregroundColor(MochiColors.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !self.updater.isUpdating
                {
                    SwiftUI.Button {
                        NotificationCenter.default.post(name: .mochiUpdateMochiLoad, object: nil)
                    } label: {
                        Text(NSLocalizedString("Update", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(MochiColors.ink)
                    }
                    .buttonStyle(.plain)
                }
            }

            if self.updater.isUpdating
            {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(Color.accentColor)
                            .frame(width: max(geometry.size.width * self.updater.progress, 8))
                            .animation(.easeOut(duration: 0.3), value: self.updater.progress)
                    }
                }
                .frame(height: 6)
            }
            else if self.model.isConnected != true
            {
                Text(NSLocalizedString("Turn on LocalDevVPN first, then tap Update.", comment: ""))
                    .font(.footnote)
                    .foregroundColor(MochiColors.warning)
            }
        }
        .padding(16)
        .mochiGlass(cornerRadius: 22)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
    }

    // MARK: - Setup

    private var setupCard: some View
    {
        VStack(spacing: 0) {
            self.setupRow(icon: "person.crop.circle",
                          title: NSLocalizedString("Apple ID", comment: ""),
                          detail: self.model.accountName.map { String(format: NSLocalizedString("Signed in as %@", comment: ""), $0) }
                              ?? NSLocalizedString("Sign in so MochiLoad can sign your apps.", comment: ""),
                          isDone: self.model.accountName != nil,
                          actionTitle: NSLocalizedString("Sign In", comment: "")) {
                NotificationCenter.default.post(name: .mochiOpenSettings, object: nil)
            }

            Divider().background(Color.white.opacity(0.08)).padding(.leading, 56)

            self.setupRow(icon: "link",
                          title: NSLocalizedString("Paired with this iPhone", comment: ""),
                          detail: self.model.isPaired
                              ? NSLocalizedString("Done. You only do this once.", comment: "")
                              : NSLocalizedString("Lets MochiLoad install apps without a computer.", comment: ""),
                          isDone: self.model.isPaired,
                          actionTitle: NSLocalizedString("Pair", comment: "")) {
                NotificationCenter.default.post(name: .mochiOpenPairing, object: nil)
            }

            Divider().background(Color.white.opacity(0.08)).padding(.leading, 56)

            self.setupRow(icon: "network",
                          title: NSLocalizedString("LocalDevVPN connected", comment: ""),
                          detail: self.connectionDetail,
                          isDone: self.model.isConnected == true,
                          isChecking: self.model.isPaired && self.model.isConnected == nil,
                          actionTitle: nil,
                          action: nil)
        }
        .mochiGlass(cornerRadius: 22)
    }

    private var connectionDetail: String {
        switch self.model.isConnected
        {
        case .some(true): return NSLocalizedString("Ready to install and refresh.", comment: "")
        case .some(false) where !self.model.isPaired: return NSLocalizedString("Pair first, then turn on LocalDevVPN.", comment: "")
        case .some(false): return NSLocalizedString("Open LocalDevVPN and tap Connect. Keep it on while installing.", comment: "")
        case .none: return NSLocalizedString("Checking…", comment: "")
        }
    }

    private func setupRow(icon: String, title: String, detail: String, isDone: Bool, isChecking: Bool = false,
                          actionTitle: String?, action: (() -> Void)?) -> some View
    {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDone ? Color(hex: 0x5EEAD4).opacity(0.18) : Color.white.opacity(0.08))
                if isChecking
                {
                    ProgressView().scaleEffect(0.7)
                }
                else
                {
                    Image(systemName: isDone ? "checkmark" : icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDone ? Color(hex: 0x5EEAD4) : MochiColors.mutedText)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(MochiColors.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(MochiColors.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if !isDone, let actionTitle, let action
            {
                SwiftUI.Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(MochiColors.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Apps

    private var appsCard: some View
    {
        VStack(spacing: 0) {
            ForEach(Array(self.model.apps.enumerated()), id: \.element.id) { index, app in
                if index > 0
                {
                    Divider().background(Color.white.opacity(0.08)).padding(.leading, 66)
                }
                HStack(spacing: 14) {
                    Group {
                        if let icon = self.model.icons[app.id]
                        {
                            Image(uiImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        else
                        {
                            Text(String(app.name.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(LinearGradient(colors: [Color.accentColor, app.color.opacity(0.8)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(app.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MochiColors.text)
                                .lineLimit(1)
                            Spacer()
                            Text(app.timeLeftText)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(app.color)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(app.color)
                                    .frame(width: max(geometry.size.width * app.fractionLeft, 6))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
        .mochiGlass(cornerRadius: 22)
    }
}

/// Wraps Home for the UIKit tab bar.
enum MochiHomeTab
{
    @MainActor
    static func makeNavigationController() -> UINavigationController
    {
        let hosting = UIHostingController(rootView: MochiHomeView())
        hosting.view.backgroundColor = UIColor(red: 11/255, green: 10/255, blue: 18/255, alpha: 1)
        let navigationController = UINavigationController(rootViewController: hosting)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.overrideUserInterfaceStyle = .dark
        navigationController.tabBarItem = UITabBarItem(title: NSLocalizedString("Home", comment: ""),
                                                       image: UIImage(systemName: "house"),
                                                       selectedImage: UIImage(systemName: "house.fill"))
        return navigationController
    }
}

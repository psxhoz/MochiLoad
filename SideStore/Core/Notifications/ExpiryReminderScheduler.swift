//
//  ExpiryReminderScheduler.swift
//  MochiLoad
//
//  Schedules local "your app expires soon" reminders for every active app,
//  so people get a heads-up before an app stops opening even if background
//  refresh never ran. Rescheduled when MochiLoad comes to the foreground,
//  goes to the background, or finishes a background refresh.
//  Needs proper testing on device.
//

import Foundation
import CoreData
import UserNotifications

enum ExpiryReminderScheduler
{
    /// UserDefaults key for the "Expiring soon" setting (on by default).
    static let enabledKey = "mochi.expiryRemindersEnabled"

    /// Every reminder identifier starts with this, so old ones can be cleared in one go.
    static let identifierPrefix = "mochi.expiry."

    /// How long before an app expires to remind: one day, then three hours.
    static let leadTimes: [TimeInterval] = [24 * 60 * 60, 3 * 60 * 60]

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private struct Entry: Sendable
    {
        let bundleID: String
        let name: String
        let expirationDate: Date
        let isSelf: Bool
    }

    /// Clears old reminders and schedules fresh ones from the current expiry dates.
    static func reschedule() async
    {
        #if !os(tvOS)
        guard DatabaseManager.shared.isStarted else { return }

        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let entries: [Entry] = await context.performAsync {
            InstalledApp.fetchActiveApps(in: context).map { app in
                let isSelf = (app.bundleIdentifier == StoreApp.altstoreAppID)
                return Entry(bundleID: app.bundleIdentifier,
                             name: isSelf ? "MochiLoad" : app.name,
                             expirationDate: app.expirationDate,
                             isSelf: isSelf)
            }
        }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard isEnabled else { return }

        let now = Date()
        for entry in entries
        {
            for lead in leadTimes
            {
                let fireDate = entry.expirationDate.addingTimeInterval(-lead)
                let delay = fireDate.timeIntervalSince(now)
                guard delay > 60 else { continue }

                let content = UNMutableNotificationContent()
                content.title = title(for: entry, lead: lead)
                content.body = body(for: entry)
                content.sound = .default
                content.threadIdentifier = "mochi.expiry"

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: "\(identifierPrefix)\(entry.bundleID).\(Int(lead))",
                                                    content: content,
                                                    trigger: trigger)
                do
                {
                    try await center.add(request)
                }
                catch
                {
                    debugLog("[ExpiryReminderScheduler] Failed to schedule reminder for \(entry.bundleID): \(error)")
                }
            }
        }
        #endif
    }

    private static func title(for entry: Entry, lead: TimeInterval) -> String
    {
        if lead >= 24 * 60 * 60
        {
            return String(format: NSLocalizedString("%@ expires tomorrow", comment: ""), entry.name)
        }

        let hours = Int(lead / 3600)
        return String(format: NSLocalizedString("%@ expires in %d hours", comment: ""), entry.name, hours)
    }

    private static func body(for entry: Entry) -> String
    {
        if entry.isSelf
        {
            return NSLocalizedString("Open MochiLoad and tap Refresh All so it and your apps keep opening. Turn on LocalDevVPN first.", comment: "")
        }

        return NSLocalizedString("Open MochiLoad and tap Refresh so it keeps opening. Turn on LocalDevVPN first.", comment: "")
    }
}

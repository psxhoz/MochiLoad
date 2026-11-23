//
//  MochiPairingLiveActivity.swift
//  MochiLoad
//
//  Puts the pairing code in the Dynamic Island / lock screen while pairing, so it's visible
//  in Settings even if the notification doesn't show. Safe to call from any thread.
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

enum MochiPairingLiveActivity
{
    private static let queue = DispatchQueue(label: "com.psxhoz.MochiLoad.pairingActivity")
    private static var activityBox: Any?

    /// Shows "Waiting for Settings…".
    static func start()
    {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        queue.async {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                debugLog("[MochiPairingLiveActivity] Live Activities are off.")
                return
            }

            // End any leftovers from an earlier pairing attempt.
            for activity in Activity<MochiPairingAttributes>.activities
            {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }

            let state = MochiPairingAttributes.ContentState(
                code: nil,
                title: NSLocalizedString("Ready to pair", comment: ""),
                detail: NSLocalizedString("Settings → Privacy & Security → Developer Mode → Pair with MochiLoad", comment: ""))
            do
            {
                let activity = try Activity.request(attributes: MochiPairingAttributes(),
                                                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(10 * 60)),
                                                    pushType: nil)
                activityBox = activity
            }
            catch
            {
                debugLog("[MochiPairingLiveActivity] Could not start: \(error)")
            }
        }
        #endif
    }

    /// Shows the code big.
    static func showCode(_ code: String)
    {
        let spaced = code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code
        update(code: spaced,
               title: NSLocalizedString("Your pairing code", comment: ""),
               detail: NSLocalizedString("Type it in Settings to finish pairing.", comment: ""),
               dismissAfter: nil)
    }

    /// Shows why no code is coming (stays until pairing stops).
    static func showProblem(title: String)
    {
        update(code: nil, title: title,
               detail: NSLocalizedString("Open MochiLoad to fix it.", comment: ""), didFail: true, dismissAfter: nil)
    }

    /// Shows the result for a few seconds, then goes away. `success == nil` means pairing was stopped.
    static func finish(success: Bool?)
    {
        switch success
        {
        case true?:
            update(code: nil, title: NSLocalizedString("Paired!", comment: ""),
                   detail: NSLocalizedString("Go back to MochiLoad.", comment: ""), isFinished: true, dismissAfter: 6)
        case false?:
            update(code: nil, title: NSLocalizedString("Pairing didn't work", comment: ""),
                   detail: NSLocalizedString("Open MochiLoad and try again.", comment: ""), isFinished: true, didFail: true, dismissAfter: 6)
        case nil:
            update(code: nil, title: "", detail: "", dismissAfter: 0)
        }
    }

    /// `dismissAfter`: nil = just update; 0 = remove now; > 0 = show this, then remove.
    private static func update(code: String?, title: String, detail: String, isFinished: Bool = false, didFail: Bool = false, dismissAfter: TimeInterval?)
    {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        queue.async {
            guard let activity = activityBox as? Activity<MochiPairingAttributes> else { return }
            let content = ActivityContent(state: MochiPairingAttributes.ContentState(code: code, title: title, detail: detail,
                                                                                     isFinished: isFinished, didFail: didFail),
                                          staleDate: nil)

            if let dismissAfter
            {
                activityBox = nil
                if dismissAfter <= 0
                {
                    Task { await activity.end(nil, dismissalPolicy: .immediate) }
                }
                else
                {
                    Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(dismissAfter))) }
                }
            }
            else
            {
                Task { await activity.update(content) }
            }
        }
        #endif
    }
}

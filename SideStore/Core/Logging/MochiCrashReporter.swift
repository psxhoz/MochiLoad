//
//  MochiCrashReporter.swift
//  MochiLoad
//
//  Saves the reason for a crash to a file, then shows it on the next launch with a Copy button,
//  so friends can send it over without digging through iPhone analytics.
//

import UIKit
import MachO

nonisolated(unsafe) private var mochiCrashFilePath: [CChar] = []
nonisolated(unsafe) private var mochiPreviousSignalHandlers: [Int32: sigaction] = [:]
nonisolated(unsafe) private var mochiPreviousExceptionHandler: (@convention(c) (NSException) -> Void)? = nil

enum MochiCrashReporter
{
    private static let fileName = "MochiLoad-last-crash.txt"
    private static let handledSignals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP]

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    static func install()
    {
        mochiCrashFilePath = Array(self.fileURL.path.utf8CString)

        // Keep the existing logger working too.
        mochiPreviousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            let report = MochiCrashReporter.makeReport(
                kind: "Exception: \(exception.name.rawValue)",
                reason: exception.reason ?? "(no reason)",
                stack: exception.callStackSymbols)
            MochiCrashReporter.write(report)
            mochiPreviousExceptionHandler?(exception)
        }

        for signalNumber in handledSignals
        {
            var action = sigaction()
            action.__sigaction_u.__sa_handler = { signalNumber in
                // Not strictly async-signal-safe, but good enough to capture what went wrong.
                let report = MochiCrashReporter.makeReport(
                    kind: "Signal \(signalNumber)",
                    reason: MochiCrashReporter.signalName(signalNumber),
                    stack: Thread.callStackSymbols)
                MochiCrashReporter.write(report)

                // Let iOS handle the crash as usual.
                if var previous = mochiPreviousSignalHandlers[signalNumber]
                {
                    sigaction(signalNumber, &previous, nil)
                }
                else
                {
                    signal(signalNumber, SIG_DFL)
                }
                raise(signalNumber)
            }
            sigemptyset(&action.sa_mask)
            action.sa_flags = 0

            var previous = sigaction()
            sigaction(signalNumber, &action, &previous)
            mochiPreviousSignalHandlers[signalNumber] = previous
        }
    }

    private static func signalName(_ signalNumber: Int32) -> String
    {
        switch signalNumber
        {
        case SIGABRT: return "SIGABRT (abort)"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV (bad memory access)"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGTRAP: return "SIGTRAP (Swift runtime check failed)"
        default: return "signal \(signalNumber)"
        }
    }

    private static func makeReport(kind: String, reason: String, stack: [String]) -> String
    {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (info?["CFBundleVersion"] as? String ?? "?") + ")"
        let slide = _dyld_get_image_vmaddr_slide(0)

        var lines: [String] = []
        lines.append("MochiLoad \(version) on iOS \(UIDevice.current.systemVersion)")
        lines.append("Date: \(Date())")
        lines.append(kind)
        lines.append("Reason: \(reason)")
        lines.append("Image slide: 0x" + String(slide, radix: 16))
        lines.append("")
        lines.append(contentsOf: stack.prefix(40))
        return lines.joined(separator: "\n")
    }

    private static func write(_ report: String)
    {
        guard !mochiCrashFilePath.isEmpty else { return }
        let fd = mochiCrashFilePath.withUnsafeBufferPointer { open($0.baseAddress!, O_WRONLY | O_CREAT | O_TRUNC, 0o644) }
        guard fd >= 0 else { return }
        var bytes = Array(report.utf8)
        _ = Darwin.write(fd, &bytes, bytes.count)
        close(fd)
    }

    /// Shows the saved crash once, then deletes it.
    @MainActor
    static func presentPendingReportIfNeeded(from viewController: UIViewController)
    {
        guard let report = try? String(contentsOf: self.fileURL, encoding: .utf8), !report.isEmpty else { return }
        try? FileManager.default.removeItem(at: self.fileURL)

        let reasonLine = report.split(separator: "\n").first(where: { $0.hasPrefix("Reason:") }).map(String.init) ?? ""
        let message = NSLocalizedString("MochiLoad closed unexpectedly last time. Tap Copy Details and send it to whoever set up MochiLoad for you.", comment: "") + "\n\n" + reasonLine

        let alert = UIAlertController(title: NSLocalizedString("Sorry about that", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Copy Details", comment: ""), style: .default) { _ in
            UIPasteboard.general.string = report
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel))

        var presenter = viewController
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(alert, animated: true)
    }
}

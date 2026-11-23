//
//  MochiPairingDiagnostics.swift
//  MochiLoad
//
//  While pairing, checks that Settings can actually find MochiLoad: looks for MochiLoad's own
//  pairing advertisement on the network. If Local Network access is blocked, or there's no Wi-Fi,
//  Settings never shows "Pair with MochiLoad" (or can't connect) and no code is ever sent.
//

import Foundation
import Network

enum MochiPairingProblem: Equatable
{
    /// Local Network permission is off for MochiLoad.
    case localNetworkDenied
    /// MochiLoad's pairing signal can't be seen (usually no Wi-Fi).
    case notVisible
}

final class MochiPairingDiagnostics
{
    private var browser: NWBrowser?
    private var timeoutWork: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.psxhoz.MochiLoad.pairingDiagnostics")
    private var didReport = false

    /// Calls `onResult` once on the main thread: nil = MochiLoad is visible (good), otherwise the problem.
    func start(timeout: TimeInterval = 12, onResult: @escaping (MochiPairingProblem?) -> Void)
    {
        self.stop()
        self.didReport = false

        func report(_ problem: MochiPairingProblem?)
        {
            guard !self.didReport else { return }
            self.didReport = true
            debugLog("[MochiPairingDiagnostics] result: \(String(describing: problem))")
            DispatchQueue.main.async { onResult(problem) }
            self.stop()
        }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_remotepairing-pairable-host._tcp", domain: nil), using: parameters)

        browser.stateUpdateHandler = { state in
            debugLog("[MochiPairingDiagnostics] browser state: \(state)")
            switch state
            {
            case .waiting(let error), .failed(let error):
                if case .dns(let code) = error, Int(code) == -65570 // kDNSServiceErr_PolicyDenied
                {
                    report(.localNetworkDenied)
                }
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { results, _ in
            // Any pairable host on this iPhone's network means advertising works; ours is the only one
            // normally, since it's this phone's own MochiLoad.
            if !results.isEmpty
            {
                report(nil)
            }
        }

        self.browser = browser
        browser.start(queue: self.queue)

        let timeoutWork = DispatchWorkItem { report(.notVisible) }
        self.timeoutWork = timeoutWork
        self.queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
    }

    func stop()
    {
        self.timeoutWork?.cancel()
        self.timeoutWork = nil
        self.browser?.cancel()
        self.browser = nil
    }
}

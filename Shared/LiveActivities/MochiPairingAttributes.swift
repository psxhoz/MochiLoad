//
//  MochiPairingAttributes.swift
//  MochiLoad
//
//  Data for the pairing Live Activity: shows the pairing code in the Dynamic Island and
//  on the lock screen while the person is in Settings. Shared by the app and the widget.
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct MochiPairingAttributes: ActivityAttributes
{
    public struct ContentState: Codable, Hashable
    {
        /// The 6-digit code, once Settings asks for it.
        public var code: String?
        /// e.g. "Waiting for Settings…" or "Paired!"
        public var title: String
        public var detail: String
        public var isFinished: Bool
        public var didFail: Bool

        public init(code: String?, title: String, detail: String, isFinished: Bool = false, didFail: Bool = false)
        {
            self.code = code
            self.title = title
            self.detail = detail
            self.isFinished = isFinished
            self.didFail = didFail
        }
    }

    public init() {}
}
#endif

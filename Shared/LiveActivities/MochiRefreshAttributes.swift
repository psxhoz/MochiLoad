//
//  MochiRefreshAttributes.swift
//  MochiLoad
//
//  Data for the "Refreshing apps" Live Activity on the lock screen and Dynamic Island.
//  Shared by the app (which starts and updates it) and the widget (which draws it).
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct MochiRefreshAttributes: ActivityAttributes
{
    public struct ContentState: Codable, Hashable
    {
        /// 0...1
        public var progress: Double
        /// e.g. "Refreshing 3 apps" or "All apps refreshed"
        public var title: String
        /// e.g. "Signing MochiChange…" or "Good for another 7 days"
        public var detail: String
        public var isFinished: Bool
        public var didFail: Bool

        public init(progress: Double, title: String, detail: String, isFinished: Bool = false, didFail: Bool = false)
        {
            self.progress = progress
            self.title = title
            self.detail = detail
            self.isFinished = isFinished
            self.didFail = didFail
        }
    }

    public var appCount: Int

    public init(appCount: Int)
    {
        self.appCount = appCount
    }
}
#endif

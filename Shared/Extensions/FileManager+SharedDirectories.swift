//
//  FileManager+SharedDirectories.swift
//  AltStore
//
//  Created by Riley Testut on 5/14/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

// MochiLoad: guards the one-time move of fallback data into the real App Group container.
private let mochiFallbackMigrationLock = NSLock()
private nonisolated(unsafe) var mochiDidCheckFallbackMigration = false

public extension FileManager
{
    var altstoreSharedDirectory: URL? {
        #if os(tvOS)
        return self.cachesDirectory
        #else
        // 1. The expected App Group (group.com.psxhoz.MochiLoad[.TEAMID])
        if let appGroup = Bundle.main.altstoreAppGroup,
           let sharedDirectoryURL = self.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        {
            self.mochiMigrateFallbackDirectoryIfNeeded(into: sharedDirectoryURL)
            return sharedDirectoryURL
        }

        // 2. MochiLoad: some installers rename the App Group; use whichever one the app was signed with.
        for appGroup in Bundle.main.appGroups
        {
            if let sharedDirectoryURL = self.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            {
                self.mochiMigrateFallbackDirectoryIfNeeded(into: sharedDirectoryURL)
                return sharedDirectoryURL
            }
        }

        // 3. MochiLoad: the installer dropped App Groups entirely (e.g. some first-time sideloading tools).
        //    Keep working from a private folder instead of refusing to start. The widget and backups
        //    can't see this folder, but installing and refreshing work. Once MochiLoad refreshes itself
        //    it signs in its App Group, and step 1 moves this data across. Needs proper testing.
        return self.mochiPrivateFallbackDirectory
        #endif
    }

    /// MochiLoad: private stand-in for the App Group container when the app was installed without one.
    var mochiPrivateFallbackDirectory: URL? {
        guard let appSupport = self.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let url = appSupport.appendingPathComponent("MochiLoadShared", isDirectory: true)
        try? self.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    /// MochiLoad: if earlier launches used the private fallback, move that data into the real App Group once.
    private func mochiMigrateFallbackDirectoryIfNeeded(into sharedDirectoryURL: URL)
    {
        mochiFallbackMigrationLock.lock()
        defer { mochiFallbackMigrationLock.unlock() }

        guard !mochiDidCheckFallbackMigration else { return }
        mochiDidCheckFallbackMigration = true

        guard let appSupport = self.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fallbackURL = appSupport.appendingPathComponent("MochiLoadShared", isDirectory: true)
        guard self.fileExists(atPath: fallbackURL.path),
              let items = try? self.contentsOfDirectory(at: fallbackURL, includingPropertiesForKeys: nil) else { return }

        // Don't overwrite a database that already lives in the App Group.
        let sharedDatabaseURL = sharedDirectoryURL.appendingPathComponent("Database", isDirectory: true)
        let sharedHasDatabase = ((try? self.contentsOfDirectory(atPath: sharedDatabaseURL.path)) ?? []).contains { $0.hasSuffix(".sqlite") }
        guard !sharedHasDatabase else { return }

        for item in items
        {
            let destination = sharedDirectoryURL.appendingPathComponent(item.lastPathComponent)
            if self.fileExists(atPath: destination.path)
            {
                try? self.removeItem(at: destination)
            }
            try? self.moveItem(at: item, to: destination)
        }
        try? self.removeItem(at: fallbackURL)
    }
    
    var appBackupsDirectory: URL? {
        let appBackupsDirectory = self.altstoreSharedDirectory?.appendingPathComponent("Backups", isDirectory: true)
        return appBackupsDirectory
    }
    
    func backupDirectoryURL(forBundleIdentifier bundleIdentifier: String) -> URL?
    {
        let backupDirectoryURL = self.appBackupsDirectory?.appendingPathComponent(bundleIdentifier, isDirectory: true)
        return backupDirectoryURL
    }
    
    func deleteBackup(forBundleIdentifier bundleIdentifier: String) throws
    {
        debugLog("[FileManager] deleteBackup() started for \(bundleIdentifier)")
        defer { debugLog("[FileManager] deleteBackup() completed for \(bundleIdentifier)") }
        
        guard let backupDirectoryURL = self.backupDirectoryURL(forBundleIdentifier: bundleIdentifier) else {
            debugLog("[FileManager] deleteBackup: Failed to construct backup directory URL for \(bundleIdentifier)")
            return
        }
        
        guard self.fileExists(atPath: backupDirectoryURL.path) else {
            debugLog("[FileManager] deleteBackup: No backup directory exists at \(backupDirectoryURL.path)")
            return
        }
        
        try self.removeItem(at: backupDirectoryURL)
        debugLog("[FileManager] Successfully deleted backup directory for \(bundleIdentifier) at \(backupDirectoryURL.path)")
    }
}

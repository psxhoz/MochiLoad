//
//  MochiAnisette.swift
//  MochiLoad
//
//  Signing in to Apple needs "anisette" data that proves the request comes from a real Apple device.
//  Apple keeps changing what it accepts (Oct 2026: Xcode client info blocked; Nov 17: Android-based
//  provisioning rejected with PTM/TK 401; Nov 20: "<macOS;" client info rejected with 503).
//  Instead of relying on one method, MochiLoad tries several in order, remembers the one that worked
//  and tries it first next time.
//

import Foundation
import SideSign
import AnisetteKit

enum MochiAnisette
{
    /// Mac identity spelled the way Apple's own akd does ("Mac OS X", current version).
    static let macClientInfo = AppConstants.Anisette.defaultClientInfo
    static let macUserAgent = AppConstants.Anisette.defaultUserAgent

    /// Windows (iTunes) identity, reported working with Android-based servers in Oct 2026.
    static let windowsClientInfo = "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>"
    static let windowsUserAgent = "akd/1.0 CFNetwork/808.1.4"

    /// Servers that run on real Macs, so the device data matches a Mac identity.
    static let macBackedServers: [String] = [
        "https://ani3.stikstore.app",
        "https://mac-ani.jkcoxson.com",
        "https://ani.jkcoxson.com",
        "https://ani2.stikstore.app",
        "https://ani.stikstore.app",
        "https://new.ani.sidestore.io",
    ]

    private static let lastMethodKey = "mochi.anisette.lastMethod"
    private static let lastServerKey = "mochi.anisette.lastServer"
    private static let adiBlobServerKey = "mochi.anisette.adiBlobServer"

    enum Method: String, CaseIterable
    {
        /// What fixed real SideStore for us: SideStore's "New" server, fresh provisioning.
        case sideStoreNewProvisioning
        /// Ready-made headers from a Mac-backed server (no provisioning on our side).
        case macServerHeaders
        /// v3 provisioning through a Mac-backed server, Mac identity.
        case macServerProvisioning
        /// The SideStore server list with a Windows identity.
        case serverListWindows
        /// The SideStore server list with a Mac identity.
        case serverListMac
        /// Emulated Apple libraries on this iPhone.
        case onDevice
    }

    struct AllMethodsFailed: LocalizedError
    {
        let attempts: [String]

        var errorDescription: String? {
            let message = NSLocalizedString("Apple didn't accept any of MochiLoad's sign-in helpers right now. Apple has been changing this for every sideloading app this month. Check your internet and try again in a few minutes.", comment: "")
            guard let last = self.attempts.last else { return message }
            return message + "\n\n(" + last + ")"
        }

        var failureReason: String? { self.attempts.last }

        var recoverySuggestion: String? {
            NSLocalizedString("If it keeps failing, wait an hour and try again. Apple sometimes blocks sign-ins for a while after several attempts.", comment: "")
        }
    }

    struct ServerError: LocalizedError
    {
        let message: String
        var errorDescription: String? { self.message }
    }

    // MARK: - Client info fixes

    /// Apple refuses "<macOS;…>" since 2026-11-20 and very old macOS versions (e.g. 10.12.6).
    static func sanitizedClientInfo(_ clientInfo: String) -> String
    {
        var result = clientInfo.replacingOccurrences(of: "<macOS;", with: "<Mac OS X;")

        if let range = result.range(of: #"<Mac OS X;[0-9.]+;[0-9A-Za-z]+>"#, options: .regularExpression)
        {
            let segment = result[range].dropFirst("<Mac OS X;".count)
            let version = segment.split(separator: ";").first.map(String.init) ?? ""
            if let major = Int(version.split(separator: ".").first ?? ""), major < 14
            {
                result.replaceSubrange(range, with: "<Mac OS X;26.6;25F84>")
            }
        }

        return result
    }

    // MARK: - Fetch

    /// All methods, the one that last worked first.
    static func orderedMethods() -> [Method]
    {
        var order: [Method] = [.sideStoreNewProvisioning, .macServerHeaders, .macServerProvisioning, .serverListWindows, .serverListMac, .onDevice]
        if let raw = UserDefaults.standard.string(forKey: lastMethodKey), let last = Method(rawValue: raw)
        {
            order.removeAll { $0 == last }
            order.insert(last, at: 0)
        }
        return order
    }

    /// Call after Apple accepted a sign-in made with this method.
    static func recordSuccess(_ method: Method)
    {
        UserDefaults.standard.set(method.rawValue, forKey: lastMethodKey)
    }

    /// Call when Apple rejected a sign-in made with this method.
    static func recordFailure(_ method: Method) async
    {
        if UserDefaults.standard.string(forKey: lastMethodKey) == method.rawValue
        {
            UserDefaults.standard.removeObject(forKey: lastMethodKey)
        }
        // Start the next provisioning from scratch, like "Reset adi.pb" in SideStore.
        AnisetteConfigManager.shared.anisetteAdiBlob = nil
        UserDefaults.standard.removeObject(forKey: adiBlobServerKey)
        if method == .onDevice
        {
            await OnDeviceAnisetteManager.shared.resetProvisioningState()
        }
    }

    /// For everything except sign-in (refreshing, App IDs...): first method that returns data.
    static func fetch(handler: AnisetteServerHandler?) async throws -> ALTAnisetteData
    {
        var attempts: [String] = []

        for method in self.orderedMethods()
        {
            do
            {
                return try await self.fetch(using: method)
            }
            catch
            {
                attempts.append("\(method.rawValue): \(error.localizedDescription)")
                if method == .onDevice
                {
                    await OnDeviceAnisetteManager.shared.resetProvisioningState()
                }
            }
        }

        throw AllMethodsFailed(attempts: attempts)
    }

    static func fetch(using method: Method) async throws -> ALTAnisetteData
    {
        debugLog("[MochiAnisette] Trying \(method.rawValue)...")
        do
        {
            var data = try await self.rawFetch(using: method)
            data.clientInfo = self.sanitizedClientInfo(data.clientInfo)
            debugLog("[MochiAnisette] \(method.rawValue) returned sign-in data.")
            return data
        }
        catch
        {
            debugLog("[MochiAnisette] \(method.rawValue) failed: \(error.localizedDescription)")
            throw error
        }
    }

    private static func rawFetch(using method: Method) async throws -> ALTAnisetteData
    {
        switch method
        {
        case .sideStoreNewProvisioning:
            return try await self.fetchProvisioned(servers: [URL(string: "https://new.ani.sidestore.io")!],
                                                   clientInfo: self.macClientInfo, userAgent: self.macUserAgent)

        case .macServerHeaders:
            return try await self.firstSuccess(in: self.orderedServers(self.macBackedServers)) { server in
                try await self.fetchReadyMadeHeaders(from: server)
            }

        case .macServerProvisioning:
            return try await self.fetchProvisioned(servers: self.orderedServers(self.macBackedServers),
                                                   clientInfo: self.macClientInfo, userAgent: self.macUserAgent)

        case .serverListWindows:
            return try await self.fetchProvisioned(servers: await self.userServerList(),
                                                   clientInfo: self.windowsClientInfo, userAgent: self.windowsUserAgent)

        case .serverListMac:
            return try await self.fetchProvisioned(servers: await self.userServerList(),
                                                   clientInfo: self.macClientInfo, userAgent: self.macUserAgent)

        case .onDevice:
            return try await OnDeviceAnisetteManager.shared.fetchAnisetteData()
        }
    }

    // MARK: - Servers

    /// Puts the server that worked last time first.
    private static func orderedServers(_ servers: [String]) -> [URL]
    {
        var list = servers
        if let last = UserDefaults.standard.string(forKey: lastServerKey), let index = list.firstIndex(of: last)
        {
            list.remove(at: index)
            list.insert(last, at: 0)
        }
        return list.compactMap { URL(string: $0) }
    }

    private static func userServerList() async -> [URL]
    {
        var servers = await AnisetteServersManager.shared.getActiveServerURLs()
        if servers.isEmpty
        {
            _ = try? await AnisetteServersManager.shared.syncWithRemote()
            servers = await AnisetteServersManager.shared.getActiveServerURLs()
        }
        if servers.isEmpty
        {
            servers = [AppConstants.Anisette.Servers.defaultServerURL]
        }
        // Mac-backed servers are tried separately; skip duplicates.
        let macHosts = Set(self.macBackedServers.compactMap { URL(string: $0)?.host })
        let filtered = servers.filter { URL(string: $0).map { !macHosts.contains($0.host ?? "") } ?? false }
        return self.orderedServers(filtered)
    }

    private static func firstSuccess(in servers: [URL], _ body: (URL) async throws -> ALTAnisetteData) async throws -> ALTAnisetteData
    {
        var lastError: Error = ServerError(message: NSLocalizedString("No sign-in servers to try.", comment: ""))
        for server in servers
        {
            do
            {
                let data = try await body(server)
                UserDefaults.standard.set(server.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forKey: lastServerKey)
                return data
            }
            catch
            {
                debugLog("[MochiAnisette] \(server.host ?? server.absoluteString) failed: \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError
    }

    // MARK: - Ready-made headers (classic GET /)

    /// Mac-backed servers answer a plain GET with headers generated on the Mac itself, so this iPhone
    /// never has to run Apple's provisioning step (the one returning PTM/TK 401).
    private static func fetchReadyMadeHeaders(from server: URL) async throws -> ALTAnisetteData
    {
        var request = URLRequest(url: server)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw ServerError(message: String(format: NSLocalizedString("%@ answered with HTTP %d.", comment: ""), server.host ?? "Server", status))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServerError(message: String(format: NSLocalizedString("%@ sent something MochiLoad couldn't read.", comment: ""), server.host ?? "Server"))
        }

        var values: [String: String] = [:]
        for (key, value) in json
        {
            if let string = value as? String { values[key.lowercased()] = string }
            else if let number = value as? NSNumber { values[key.lowercased()] = number.stringValue }
        }
        func value(_ key: String) -> String? {
            guard let v = values[key.lowercased()], !v.isEmpty else { return nil }
            return v
        }

        guard let oneTimePassword = value("X-Apple-I-MD"), let machineID = value("X-Apple-I-MD-M") else {
            throw ServerError(message: String(format: NSLocalizedString("%@ didn't send sign-in data.", comment: ""), server.host ?? "Server"))
        }

        let identifier = await AnisetteConfigManager.shared.resolveDeviceIdentifier()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let headers: [String: String] = [
            "X-Apple-I-MD": oneTimePassword,
            "X-Apple-I-MD-M": machineID,
            "X-Apple-I-MD-LU": value("X-Apple-I-MD-LU") ?? identifier.uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            "X-Apple-I-MD-RINFO": value("X-Apple-I-MD-RINFO") ?? "17106176",
            "X-Mme-Device-Id": value("X-Mme-Device-Id") ?? identifier.uuidString.uppercased(),
            "X-Apple-I-SRL-NO": value("X-Apple-I-SRL-NO") ?? "0",
            "X-Mme-Client-Info": self.sanitizedClientInfo(value("X-Mme-Client-Info") ?? self.macClientInfo),
            "User-Agent": self.macUserAgent,
            "X-Apple-I-Client-Time": value("X-Apple-I-Client-Time") ?? formatter.string(from: Date()),
            "X-Apple-Locale": value("X-Apple-Locale") ?? Locale.current.identifier,
            "X-Apple-I-TimeZone": value("X-Apple-I-TimeZone") ?? (TimeZone.current.abbreviation() ?? "UTC"),
        ]

        return try SideSign.AnisetteDataManager.validateAndCreateAnisetteData(from: headers)
    }

    // MARK: - v3 provisioning

    private static func fetchProvisioned(servers: [URL], clientInfo: String, userAgent: String) async throws -> ALTAnisetteData
    {
        let identifier = await AnisetteConfigManager.shared.resolveDeviceIdentifier()
        let baseHeaders = await AnisetteConfigManager.shared.makeRequestHeaders()

        return try await self.firstSuccess(in: servers) { server in
            let serverKey = server.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "|" + clientInfo

            // A provisioning blob only works with the server (and identity) that created it.
            var existingBlob: Data? = nil
            if UserDefaults.standard.string(forKey: adiBlobServerKey) == serverKey,
               let base64 = AnisetteConfigManager.shared.anisetteAdiBlob
            {
                existingBlob = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
            }

            let headers = baseHeaders.with {
                $0.clientInfo = clientInfo
                $0.userAgent = userAgent
            }

            let (data, newBlob) = try await SideSign.AnisetteDataManager.shared.fetchAnisetteDataWithFailover(
                servers: [server],
                identifier: identifier,
                existingAdiBlob: existingBlob,
                headers: headers
            )

            if let newBlob
            {
                AnisetteConfigManager.shared.anisetteAdiBlob = newBlob.base64EncodedString()
                UserDefaults.standard.set(serverKey, forKey: adiBlobServerKey)
            }

            return data
        }
    }
}

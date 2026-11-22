//
//  AnisetteProvider.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SideSign

enum AnisetteProvider {
    static func fetch(handler: AnisetteServerHandler? = nil) async throws -> ALTAnisetteData {
        if UserDefaults.standard.useOnDeviceAnisette {
            debugLog("[AnisetteProvider] Fetching anisette via On-Device Anisette (ODA)...")
            do {
                return try await OnDeviceAnisetteManager.shared.fetchAnisetteData()
            } catch let onDeviceError {
                // MochiLoad: Apple sometimes rejects on-device provisioning (HTTP 401 from PTM/TK), and the
                // half-finished attempt then blocks the next one ("Pending ADI session"). Clear it and use
                // the remote servers instead, and remember that choice so sign-in and refresh keep working.
                debugLog("[AnisetteProvider] ODA failed (\(onDeviceError.localizedDescription)); falling back to remote servers")
                await OnDeviceAnisetteManager.shared.resetProvisioningState()
                do {
                    let data = try await fetchRemote(handler: handler)
                    UserDefaults.standard.useOnDeviceAnisette = false
                    return data
                } catch {
                    debugLog("[AnisetteProvider] Remote fallback failed too: \(error.localizedDescription)")
                    throw onDeviceError
                }
            }
        } else {
            debugLog("[AnisetteProvider] Fetching anisette via remote server...")
            do {
                return try await fetchRemote(handler: handler)
            } catch let remoteError {
                // MochiLoad: if every server is down, try the on-device way before giving up.
                debugLog("[AnisetteProvider] Remote failed (\(remoteError.localizedDescription)); trying ODA")
                do {
                    return try await OnDeviceAnisetteManager.shared.fetchAnisetteData()
                } catch {
                    await OnDeviceAnisetteManager.shared.resetProvisioningState()
                    throw remoteError
                }
            }
        }
    }

    private static func fetchRemote(handler: AnisetteServerHandler? = nil) async throws -> ALTAnisetteData {
        var serverUrlStrings = await AnisetteServersManager.shared.getActiveServerURLs()
        if serverUrlStrings.isEmpty {
            // MochiLoad: first run (or ODA was on), so the server list was never downloaded.
            _ = try? await AnisetteServersManager.shared.syncWithRemote()
            serverUrlStrings = await AnisetteServersManager.shared.getActiveServerURLs()
        }
        if serverUrlStrings.isEmpty {
            serverUrlStrings = [AppConstants.Anisette.Servers.defaultServerURL]
        }
        let servers = serverUrlStrings.compactMap { URL(string: $0) }
        guard !servers.isEmpty else {
            throw AnisetteError.noServersConfigured
        }

        let lastServer = UserDefaults.standard.menuAnisetteURL
        let startIndex = servers.firstIndex(where: { $0.absoluteString == lastServer }) ?? 0

        let provider = SideSign.AnisetteDataManager.shared
        let existingBlob = AnisetteConfigManager.shared.anisetteAdiBlob.flatMap { Data(base64Encoded: $0) }
        let identifier = await AnisetteConfigManager.shared.resolveDeviceIdentifier()
        let headers = await AnisetteConfigManager.shared.makeRequestHeaders()

        let (anisetteData, newAdiBlob) = try await provider.fetchAnisetteDataWithFailover(
            servers: UserDefaults.standard.disableAnisetteRotation ? [servers[startIndex]] : servers,
            startIndex: startIndex,
            identifier: identifier,
            existingAdiBlob: existingBlob,
            headers: headers,
            onError: { error in
                if let anisetteError = error as? SideSign.AnisetteError,
                   case .outdatedV1Server(let serverURL, _) = anisetteError {
                    if UserDefaults.standard.defaultServerURL == serverURL.absoluteString {
                        return true
                    }
                    if let handler = handler {
                        let shouldContinue = try await handler.warnOutdatedAnisetteServer()
                        if shouldContinue {
                            UserDefaults.standard.defaultServerURL = serverURL.absoluteString
                        }
                        return shouldContinue
                    }
                }
                return false
            },
            onSuccess: { successfulServer in
                UserDefaults.standard.menuAnisetteURL = successfulServer.absoluteString
                debugLog("[AnisetteProvider] Successfully fetched Anisette data from \(successfulServer.absoluteString)")
            }
        )

        if let freshBlob = newAdiBlob {
            AnisetteConfigManager.shared.anisetteAdiBlob = freshBlob.base64EncodedString()
        }

        return anisetteData
    }
}

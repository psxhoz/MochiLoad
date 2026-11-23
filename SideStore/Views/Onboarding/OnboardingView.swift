//
//  OnboardingView.swift
//  SideStore
//
//  Created by SternXD on 9/13/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Minimuxer
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct OnboardingView: View {
    var onFinish: (() -> Void)? = nil
    @State private var currentStep = 0
    private let totalSteps = 5

    var body: some View {
        ZStack {
            // MochiLoad: moving aurora background behind every setup step
            MochiAuroraBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    WelcomeStep(onNext: { currentStep += 1 })
                        .tag(0)

                    PairingFileStep(onNext: { currentStep += 1 })
                        .tag(1)

                    LocalDevVPNStep(onNext: { currentStep += 1 })
                        .tag(2)

                    AppleIDStep(onNext: { currentStep += 1 })
                        .tag(3)

                    CompleteStep(onFinish: complete)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)
                #if !os(tvOS)
                    .highPriorityGesture(
                        DragGesture().onEnded { value in
                            if value.translation.width > 50, currentStep > 0, currentStep < totalSteps - 1 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentStep -= 1
                                }
                            }
                        }
                    )
                #endif
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(0 ..< totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? Color.accentColor : Color.white.opacity(0.22))
                        .frame(width: index == currentStep ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            if currentStep > 0 && currentStep < totalSteps - 1 {
                HStack {
                    SwiftUI.Button(action: { currentStep -= 1 }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 44)
    }

    private func complete() {
        UserDefaults.standard.hasCompletedOnboarding = true
        UserDefaults.standard.synchronize()
        onFinish?()
    }
}

private struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var isFloating = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") ?? UIImage(systemName: "app.fill")!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
                    .offset(y: isFloating ? -6 : 0)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isFloating)
                    .onAppear { isFloating = true }
                    .padding(.top, 28)

                VStack(spacing: 10) {
                    Text(NSLocalizedString("Apps the App Store doesn't have.", comment: ""))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(MochiColors.text)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("MochiLoad installs apps from a file or a link, signed with your own Apple ID. After setup, you never need a computer.", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(MochiColors.mutedText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 0) {
                    setupRow(1,
                             NSLocalizedString("Connect to this iPhone", comment: ""),
                             NSLocalizedString("A one-time pairing. On iOS 27 it happens right in Settings.", comment: ""))
                    divider
                    setupRow(2,
                             NSLocalizedString("Turn on LocalDevVPN", comment: ""),
                             NSLocalizedString("A free App Store app that lets installs happen on your phone.", comment: ""))
                    divider
                    setupRow(3,
                             NSLocalizedString("Sign in with your Apple ID", comment: ""),
                             NSLocalizedString("Only used to sign your apps. A spare Apple ID works too.", comment: ""))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .mochiGlass()

                SwiftUI.Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("Get Started", comment: ""))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(MochiPrimaryButtonStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
    }

    private func setupRow(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MochiColors.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(MochiColors.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

private struct PairingFileStep: View {
    let onNext: () -> Void
    @State private var hasPairingFile = PairingFileManager.shared.hasPairingFile()
    @State private var isShowingFilePicker = false
    @State private var errorMessage: String? = nil
    // MochiLoad: on-device pairing through Settings → Privacy & Security → Developer Mode (iOS 27+)
    @StateObject private var pairing = WirelessPairViewModel()

    private let contentTypes: [UTType] = PairingFileManager.supportedContentTypes

    private var supportsOnDevicePairing: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Image(systemName: hasPairingFile ? "checkmark.seal.fill" : "link.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundColor(hasPairingFile ? Color(hex: 0x5EEAD4) : .accentColor)
                    .padding(.top, 24)
                    .animation(.easeInOut, value: hasPairingFile)

                VStack(spacing: 8) {
                    Text(hasPairingFile
                         ? NSLocalizedString("You're paired!", comment: "")
                         : NSLocalizedString("Connect to this iPhone", comment: ""))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(MochiColors.text)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("MochiLoad needs a one-time \"pairing\" so it can install apps on this iPhone. Think of it as plugging into a computer, without the cable.", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(MochiColors.mutedText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                if !hasPairingFile {
                    if supportsOnDevicePairing {
                        automaticPairingCard
                    } else {
                        Text(NSLocalizedString("Automatic pairing needs iOS 27 or later. On this iPhone, use a pairing file made on a computer instead.", comment: ""))
                            .font(.footnote)
                            .foregroundColor(MochiColors.mutedText)
                            .multilineTextAlignment(.center)
                            .padding(14)
                            .mochiGlass(cornerRadius: 16)
                    }

                    #if !os(tvOS)
                    VStack(spacing: 8) {
                        SwiftUI.Button(action: { isShowingFilePicker = true }) {
                            Label(NSLocalizedString("Use a pairing file from a computer", comment: ""), systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(MochiSecondaryButtonStyle())

                        SwiftUI.Button(action: { UIApplication.shared.open(AppConstants.URLs.pairingDocumentation) }) {
                            Text(NSLocalizedString("How do I make a pairing file?", comment: ""))
                                .font(.footnote)
                                .foregroundColor(MochiColors.mutedText)
                                .underline()
                        }
                    }
                    #endif
                } else {
                    Label(NSLocalizedString("Pairing is saved. You won't need to do this again unless you reset your passcode.", comment: ""), systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundColor(MochiColors.text)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mochiGlass(cornerRadius: 16)
                }

                if let message = errorMessage ?? pairing.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(MochiColors.warning)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    SwiftUI.Button(action: onNext) {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    .buttonStyle(MochiPrimaryButtonStyle(isEnabled: hasPairingFile))
                    .disabled(!hasPairingFile)

                    if !hasPairingFile {
                        SwiftUI.Button(action: onNext) {
                            Text(NSLocalizedString("Set Up Later", comment: ""))
                                .font(.footnote)
                                .foregroundColor(MochiColors.mutedText)
                                .padding(8)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .onAppear {
            pairing.presentsShareSheetOnSuccess = false
            pairing.activatesPairingOnSuccess = true
        }
        .onDisappear {
            if pairing.isAdvertising { pairing.stopPairing() }
        }
        .onChange(of: pairing.didActivatePairing) { activated in
            guard activated else { return }
            hasPairingFile = true
            errorMessage = nil
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                do {
                    try PairingFileManager.shared.importPairingFile(from: url)
                    hasPairingFile = true
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        #endif
    }

    // MochiLoad: the no-computer way. Needs proper testing on iOS 27 devices.
    private var automaticPairingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("Pair automatically", comment: ""))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(MochiColors.text)
                Spacer()
                Text(NSLocalizedString("No computer", comment: ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MochiColors.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: 0x5EEAD4)))
            }

            VStack(alignment: .leading, spacing: 10) {
                stepRow(1, NSLocalizedString("Tap Start pairing below. Tap Allow for Local Network and Notifications — both are needed.", comment: ""))
                stepRow(2, NSLocalizedString("Open the Settings app → Privacy & Security → Developer Mode.", comment: ""))
                stepRow(3, NSLocalizedString("Tap \"Pair with MochiLoad\" and type the code from the notification.", comment: ""))
                stepRow(4, NSLocalizedString("Come back here. That's it.", comment: ""))
            }

            if pairing.isAdvertising, let problem = pairing.pairingProblem {
                MochiPairingProblemBanner(problem: problem)
            }

            if pairing.isAdvertising && pairing.notificationsOff {
                MochiNotificationsOffBanner()
            }

            if pairing.isAdvertising {
                VStack(spacing: 6) {
                    if let pin = pairing.pinCode {
                        Text(NSLocalizedString("Your code", comment: ""))
                            .mochiSectionLabel()
                        Text(pin)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundColor(MochiColors.text)
                            .tracking(4)
                        Text(NSLocalizedString("Type this code in Settings. It's also in your notifications.", comment: ""))
                            .font(.footnote)
                            .foregroundColor(MochiColors.mutedText)
                            .multilineTextAlignment(.center)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(NSLocalizedString("Waiting for Settings…", comment: ""))
                                .font(.footnote)
                                .foregroundColor(MochiColors.mutedText)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            SwiftUI.Button(action: togglePairing) {
                Text(pairing.isAdvertising
                     ? NSLocalizedString("Stop", comment: "")
                     : NSLocalizedString("Start pairing", comment: ""))
            }
            .buttonStyle(MochiPrimaryButtonStyle())
        }
        .padding(16)
        .mochiGlass()
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            Text(text)
                .font(.subheadline)
                .foregroundColor(MochiColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func togglePairing() {
        errorMessage = nil
        if pairing.isAdvertising {
            pairing.stopPairing()
            return
        }
        // startPairing() asks for notifications first if needed.
        pairing.startPairing()
    }
}

private struct LocalDevVPNStep: View {
    let onNext: () -> Void
    @State private var isConnected = false
    @State private var errorMessage: String? = nil

    private let vpnSchemeURL = URL(string: "localdevvpn://")!
    private let vpnConnectURL = URL(string: "localdevvpn://enable?scheme=sidestore")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    private var isInstalled: Bool {
        UIApplication.shared.canOpenURL(vpnSchemeURL)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                if let uiImage = UIImage(named: "LocalDevVPN") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    Image(systemName: "network")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)
                }

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    #if !os(tvOS)
                        .background(Circle().fill(Color(.systemBackground)))
                    #else
                        .background(Circle().fill(Color.black))
                    #endif
                        .offset(x: 4, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: isConnected)

            VStack(spacing: 8) {
                Text(NSLocalizedString("LocalDevVPN", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(NSLocalizedString("MochiLoad communicates with on-device services over a local loopback VPN. Enable LocalDevVPN before verifying.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("LocalDevVPN is connected.", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 12) {
                if !isConnected {
                    SwiftUI.Button(action: verifyVPN) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.horizontal.fill")
                            Text(NSLocalizedString("Verify VPN", comment: ""))
                        }
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }

                if let errorMessage {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)

                        if !isInstalled {
                            SwiftUI.Button(action: {
                                UIApplication.shared.open(appStoreURL)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.app")
                                    Text(NSLocalizedString("Get LocalDevVPN on App Store", comment: ""))
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Continue", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isConnected ? Color.accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!isConnected)

                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Set Up Later", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            checkStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkStatus()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                checkStatus()
            }
        }
    }

    private func checkStatus() {
        let interfaces = Minimuxer.shared.network.activeInterfaces
        let hasVpnTunnel = interfaces.contains { info in
            info.name.lowercased().hasPrefix("utun") && info.ip.hasPrefix("10.7.")
        }

        if hasVpnTunnel {
            isConnected = true
            errorMessage = nil
            return
        }

        let targetIp = ConnectionConfig.shared.tunnelPeerIp ?? "10.7.0.1"
        if !targetIp.isEmpty, Minimuxer.shared.core.testDeviceConnection(ifaddr: targetIp, timeout: 200) {
            isConnected = true
            errorMessage = nil
        } else {
            isConnected = false
            if isInstalled, errorMessage == NSLocalizedString("LocalDevVPN is not installed on this device.", comment: "") {
                errorMessage = nil
            }
        }
    }

    private func verifyVPN() {
        checkStatus()
        if isConnected {
            errorMessage = nil
            return
        }

        if isInstalled {
            errorMessage = nil
            UIApplication.shared.open(vpnConnectURL, options: [:]) { success in
                if !success {
                    errorMessage = NSLocalizedString("LocalDevVPN is not installed on this device.", comment: "")
                }
            }
        } else {
            UIApplication.shared.open(vpnConnectURL, options: [:]) { success in
                if !success {
                    errorMessage = NSLocalizedString("LocalDevVPN is not installed on this device.", comment: "")
                }
            }
        }
    }
}

private struct AppleIDStep: View {
    let onNext: () -> Void
    @State private var isAuthenticated = AuthManager.shared.isAuthenticated
    @State private var isSigningIn = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(isAuthenticated ? .green : .accentColor)
                .animation(.easeInOut, value: isAuthenticated)

            VStack(spacing: 8) {
                Text(NSLocalizedString("Apple ID", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(NSLocalizedString("MochiLoad requires an Apple ID to create development certificates and provisioning profiles for signing apps.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isAuthenticated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(AuthManager.shared.currentAppleID ?? NSLocalizedString("Signed in", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                SwiftUI.Button(action: {
                    Task {
                        isSigningIn = true
                        errorMessage = nil
                        defer { isSigningIn = false }

                        do {
                            _ = try await AuthManager.shared.signIn(
                                presentingViewController: UIApplication.shared.topViewController(),
                                skipResign: true,
                                skipHowTos: true
                            )
                            isAuthenticated = true
                            onNext()
                        } catch {
                            if !(error is CancellationError) {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "key.fill")
                        }
                        Text(NSLocalizedString("Sign In with Apple ID", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)
                .frame(maxWidth: 420)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Continue", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isAuthenticated ? Color.accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(!isAuthenticated && !isSigningIn)

                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Set Up Later", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct CompleteStep: View {
    let onFinish: () -> Void

    private var hasPairingFile: Bool {
        PairingFileManager.shared.hasPairingFile()
    }

    private var isAuthenticated: Bool {
        AuthManager.shared.isAuthenticated
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPairingFile ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(hasPairingFile ? .green : .orange)

            VStack(spacing: 8) {
                Text(hasPairingFile
                    ? NSLocalizedString("You're All Set!", comment: "")
                    : NSLocalizedString("Setup Incomplete", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(hasPairingFile
                    ? NSLocalizedString("MochiLoad setup is complete. You can now install and refresh apps.", comment: "")
                    : NSLocalizedString("You can enter MochiLoad, but a pairing file is required before you can install or refresh apps.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                summaryRow(
                    title: NSLocalizedString("Pairing File", comment: ""),
                    isConfigured: hasPairingFile,
                    warning: NSLocalizedString("Required before installing or refreshing apps", comment: "")
                )

                Divider()

                summaryRow(
                    title: NSLocalizedString("Apple ID", comment: ""),
                    isConfigured: isAuthenticated,
                    warning: NSLocalizedString("Can be added anytime in Settings", comment: "")
                )
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)

            Spacer()

            SwiftUI.Button(action: onFinish) {
                Text(NSLocalizedString("Open MochiLoad", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(14)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func summaryRow(title: String, isConfigured: Bool, warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isConfigured ? .green : .orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isConfigured {
                    Text(NSLocalizedString("Configured", comment: ""))
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text(NSLocalizedString("Not Configured", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

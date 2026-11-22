//
//  MochiStyle.swift
//  MochiLoad
//
//  MochiLoad's shared look: a slowly moving "aurora" background, frosted glass
//  cards and buttons. Background style and motion are user settings.
//

import SwiftUI

/// The three background looks people can pick in Settings.
enum MochiBackgroundStyle: String, CaseIterable, Identifiable
{
    case aurora = "Aurora"
    case nebula = "Nebula"
    case midnight = "Midnight"

    var id: String { self.rawValue }

    static let userDefaultsKey = "mochi.backgroundStyle"
    static let liveUserDefaultsKey = "mochi.liveBackground"

    var colors: [Color] {
        switch self
        {
        case .aurora:   return [Color(hex: 0x7C3AED), Color(hex: 0x0D9488), Color(hex: 0x2563EB)]
        case .nebula:   return [Color(hex: 0xC026D3), Color(hex: 0x4338CA), Color(hex: 0xEA580C)]
        case .midnight: return [Color(hex: 0x312E81), Color(hex: 0x1E293B), Color(hex: 0x4C1D95)]
        }
    }

    /// One-line description shown under the picker.
    var blurb: String {
        switch self
        {
        case .aurora:   return NSLocalizedString("Violet, teal and blue.", comment: "")
        case .nebula:   return NSLocalizedString("Magenta, indigo and orange.", comment: "")
        case .midnight: return NSLocalizedString("Deep and dark, easy on the eyes at night.", comment: "")
        }
    }
}

enum MochiColors
{
    /// The near-black ink every screen sits on.
    static let ink = Color(hex: 0x0B0A12)
    static let text = Color(hex: 0xF2F0FA)
    static let mutedText = Color(hex: 0xA9A3BF)
    static let warning = Color(hex: 0xFDBA74)
}

extension Color
{
    /// MochiLoad: build a color from 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1)
    {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Slowly drifting, blurred color blobs on dark ink. Respects Reduce Motion and the
/// "Live background" setting.
struct MochiAuroraBackground: View
{
    @AppStorage(MochiBackgroundStyle.userDefaultsKey) private var styleRaw: String = MochiBackgroundStyle.aurora.rawValue
    @AppStorage(MochiBackgroundStyle.liveUserDefaultsKey) private var isLive: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drift = false

    private var style: MochiBackgroundStyle { MochiBackgroundStyle(rawValue: self.styleRaw) ?? .aurora }
    private var shouldAnimate: Bool { self.isLive && !self.reduceMotion }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let colors = self.style.colors

            ZStack {
                MochiColors.ink

                self.blob(colors[0], size: w * 1.0)
                    .offset(x: self.drift ? -w * 0.12 : -w * 0.34, y: self.drift ? -h * 0.28 : -h * 0.40)

                self.blob(colors[1], size: w * 0.9)
                    .offset(x: self.drift ? w * 0.28 : w * 0.46, y: self.drift ? h * 0.06 : -h * 0.08)

                self.blob(colors[2], size: w * 0.85)
                    .offset(x: self.drift ? -w * 0.22 : -w * 0.04, y: self.drift ? h * 0.42 : h * 0.30)
            }
            .frame(width: w, height: h)
            .animation(.easeInOut(duration: 0.8), value: self.styleRaw)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { self.updateDrift() }
        .onChange(of: self.isLive) { _ in self.updateDrift() }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View
    {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size * 0.22)
            .opacity(0.55)
    }

    private func updateDrift()
    {
        if self.shouldAnimate
        {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                self.drift = true
            }
        }
        else
        {
            withAnimation(.easeInOut(duration: 0.6)) {
                self.drift = false
            }
        }
    }
}

/// Frosted glass card.
struct MochiGlass: ViewModifier
{
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View
    {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

extension View
{
    func mochiGlass(cornerRadius: CGFloat = 22) -> some View
    {
        self.modifier(MochiGlass(cornerRadius: cornerRadius))
    }

    /// Small uppercase section label, like "APP SLOTS".
    func mochiSectionLabel() -> some View
    {
        self.font(.system(size: 12, weight: .semibold))
            .textCase(.uppercase)
            .foregroundColor(MochiColors.mutedText)
    }
}

/// Big filled button in the accent color.
struct MochiPrimaryButtonStyle: ButtonStyle
{
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View
    {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(MochiColors.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(self.isEnabled ? Color.accentColor : Color.white.opacity(0.18))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Glass button for second choices.
struct MochiSecondaryButtonStyle: ButtonStyle
{
    func makeBody(configuration: Configuration) -> some View
    {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(MochiColors.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .mochiGlass(cornerRadius: 16)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

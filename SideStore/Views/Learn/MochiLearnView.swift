//
//  MochiLearnView.swift
//  MochiLoad
//
//  Plain-English answers for people who have never sideloaded before.
//  Shown as the "Learn" tab.
//

import SwiftUI
import UIKit

private struct LearnItem: Identifiable
{
    let id: String
    let question: String
    let short: String
    let answer: String
    let icon: String
}

private let learnItems: [LearnItem] = [
    LearnItem(id: "slots",
              question: NSLocalizedString("Why only 3 apps?", comment: ""),
              short: NSLocalizedString("Apple's rule for free Apple IDs.", comment: ""),
              answer: NSLocalizedString("Apple lets a free Apple ID run 3 sideloaded apps at the same time. MochiLoad is one of them, so you get 2 more. To try a different app, remove one to free its slot.\n\nApple also allows only 10 new app IDs a week on a free account, so swapping apps a lot can mean a short wait.", comment: ""),
              icon: "square.grid.3x1.below.line.grid.1x2"),
    LearnItem(id: "ipa",
              question: NSLocalizedString("What's an IPA?", comment: ""),
              short: NSLocalizedString("The file an iPhone app comes in.", comment: ""),
              answer: NSLocalizedString("An IPA is a packed-up iPhone app, a bit like a zip file. Get one from a source in Browse, or open one you already have, and MochiLoad installs it.", comment: ""),
              icon: "shippingbox"),
    LearnItem(id: "sideload",
              question: NSLocalizedString("What's sideloading?", comment: ""),
              short: NSLocalizedString("Installing apps from outside the App Store.", comment: ""),
              answer: NSLocalizedString("Sideloading means installing an app that didn't come from the App Store. Your iPhone only opens apps it trusts, so MochiLoad signs each one with your Apple ID first.", comment: ""),
              icon: "arrow.down.app"),
    LearnItem(id: "week",
              question: NSLocalizedString("Why do apps expire after 7 days?", comment: ""),
              short: NSLocalizedString("Free signatures only last a week.", comment: ""),
              answer: NSLocalizedString("Apps signed with a free Apple ID stop opening after 7 days. Refreshing signs them again before that happens, and your app's data stays put. MochiLoad reminds you a day before, and auto-refresh can do it for you.", comment: ""),
              icon: "clock.arrow.circlepath"),
    LearnItem(id: "vpn",
              question: NSLocalizedString("What's LocalDevVPN for?", comment: ""),
              short: NSLocalizedString("It lets installs happen on your phone.", comment: ""),
              answer: NSLocalizedString("LocalDevVPN lets MochiLoad talk to your iPhone the way a computer would, so it can install and refresh apps without a cable. Turn it on before you install or refresh.", comment: ""),
              icon: "network"),
    LearnItem(id: "pairing",
              question: NSLocalizedString("What's pairing?", comment: ""),
              short: NSLocalizedString("A one-time handshake with your iPhone.", comment: ""),
              answer: NSLocalizedString("Pairing gives MochiLoad permission to install apps on this iPhone, like trusting a computer. On iOS 27 and later it happens in Settings → Privacy & Security → Developer Mode. You only redo it if you reset your passcode.", comment: ""),
              icon: "link"),
    LearnItem(id: "appleid",
              question: NSLocalizedString("Is my Apple ID safe?", comment: ""),
              short: NSLocalizedString("It's only used to sign your apps.", comment: ""),
              answer: NSLocalizedString("MochiLoad signs in with Apple to make the certificate your apps need. It never buys or posts anything. If you'd rather, use a spare Apple ID just for this.", comment: ""),
              icon: "person.badge.shield.checkmark"),
    LearnItem(id: "certificate",
              question: NSLocalizedString("What's a certificate?", comment: ""),
              short: NSLocalizedString("Proof the apps were signed by you.", comment: ""),
              answer: NSLocalizedString("A certificate is how your iPhone knows an app was signed by your Apple ID. MochiLoad makes and renews it for you. You can see it in Settings.", comment: ""),
              icon: "checkmark.seal"),
    LearnItem(id: "updates",
              question: NSLocalizedString("How does MochiLoad update?", comment: ""),
              short: NSLocalizedString("By itself, when you open it.", comment: ""),
              answer: NSLocalizedString("When a new version is out, MochiLoad installs it the next time you open it with LocalDevVPN on. It closes for a moment while it swaps itself out, then a notification says it's ready. Your apps, sign-in and pairing stay. You can also tap Update on Home.", comment: ""),
              icon: "arrow.down.circle"),
]

/// The explainer cards, used on the Home tab.
struct MochiLearnCards: View
{
    @State private var openID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(learnItems) { item in
                self.card(for: item)
            }
        }
    }

    private func card(for item: LearnItem) -> some View
    {
        let isOpen = (self.openID == item.id)

        return VStack(alignment: .leading, spacing: 0) {
            SwiftUI.Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.openID = isOpen ? nil : item.id
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.question)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(MochiColors.text)
                        Text(item.short)
                            .font(.footnote)
                            .foregroundColor(MochiColors.mutedText)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MochiColors.mutedText)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOpen ? Text(NSLocalizedString("Collapses the answer", comment: "")) : Text(NSLocalizedString("Shows the answer", comment: "")))

            if isOpen
            {
                VStack(alignment: .leading, spacing: 14) {
                    if item.id == "slots"
                    {
                        self.slotsPicture
                    }
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundColor(MochiColors.text.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .mochiGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isOpen ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }

    private var slotsPicture: some View
    {
        HStack(spacing: 8) {
            self.slot(NSLocalizedString("MochiLoad", comment: ""), NSLocalizedString("always here", comment: ""), filled: true)
            self.slot(NSLocalizedString("Your app", comment: ""), NSLocalizedString("slot 2", comment: ""), filled: false)
            self.slot(NSLocalizedString("Your app", comment: ""), NSLocalizedString("slot 3", comment: ""), filled: false)
        }
        .accessibilityElement(children: .combine)
    }

    private func slot(_ title: String, _ subtitle: String, filled: Bool) -> some View
    {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MochiColors.text)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(MochiColors.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(filled ? Color.white.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(filled ? Color.accentColor : Color.white.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: filled ? [] : [5, 4]))
        )
    }
}

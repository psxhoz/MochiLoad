//
//  MochiPairingActivityWidget.swift
//  MochiLoad
//
//  Pairing code in the Dynamic Island and on the lock screen.
//

import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

private let pairInk = Color(.sRGB, red: 11/255, green: 10/255, blue: 18/255)
private let pairLavender = Color(.sRGB, red: 167/255, green: 139/255, blue: 250/255)
private let pairMint = Color(.sRGB, red: 94/255, green: 234/255, blue: 212/255)
private let pairOrange = Color(.sRGB, red: 253/255, green: 186/255, blue: 116/255)

struct MochiPairingActivityWidget: Widget
{
    var body: some WidgetConfiguration {
        if #available(iOSApplicationExtension 16.2, *)
        {
            return ActivityConfiguration(for: MochiPairingAttributes.self) { context in
                PairingLockScreenView(state: context.state)
                    .activityBackgroundTint(pairInk.opacity(0.85))
                    .activitySystemActionForegroundColor(.white)
            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        PairingCatIcon(size: 36)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Image(systemName: pairingSymbol(context.state))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(pairingColor(context.state))
                    }
                    DynamicIslandExpandedRegion(.center) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        if let code = context.state.code
                        {
                            Text(code)
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        else
                        {
                            Text(context.state.detail)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } compactLeading: {
                    PairingCatIcon(size: 22)
                } compactTrailing: {
                    if let code = context.state.code
                    {
                        // Small but readable: the whole code fits next to the island.
                        Text(code.replacingOccurrences(of: " ", with: ""))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(pairLavender)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    else
                    {
                        Image(systemName: pairingSymbol(context.state))
                            .foregroundColor(pairingColor(context.state))
                    }
                } minimal: {
                    Image(systemName: pairingSymbol(context.state))
                        .foregroundColor(pairingColor(context.state))
                }
                .keylineTint(pairLavender)
            }
        }
        else
        {
            return EmptyWidgetConfiguration()
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private func pairingSymbol(_ state: MochiPairingAttributes.ContentState) -> String
{
    if state.didFail { return "exclamationmark.circle.fill" }
    if state.isFinished { return "checkmark.circle.fill" }
    if state.code != nil { return "key.fill" }
    return "link"
}

@available(iOSApplicationExtension 16.1, *)
private func pairingColor(_ state: MochiPairingAttributes.ContentState) -> Color
{
    if state.didFail { return pairOrange }
    if state.isFinished { return pairMint }
    return pairLavender
}

private struct PairingCatIcon: View
{
    let size: CGFloat

    var body: some View {
        Image("SideStore") // the cat icon in the widget's assets
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct PairingLockScreenView: View
{
    let state: MochiPairingAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            PairingCatIcon(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                if let code = state.code
                {
                    Text(code)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Text(state.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: pairingSymbol(state))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(pairingColor(state))
        }
        .padding(16)
    }
}

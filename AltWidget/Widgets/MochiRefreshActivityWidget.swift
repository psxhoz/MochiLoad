//
//  MochiRefreshActivityWidget.swift
//  MochiLoad
//
//  Lock screen + Dynamic Island view for "Refreshing apps".
//

import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

private let mochiInk = Color(.sRGB, red: 11/255, green: 10/255, blue: 18/255)
private let mochiDeep = Color(.sRGB, red: 42/255, green: 27/255, blue: 92/255)
private let mochiLavender = Color(.sRGB, red: 167/255, green: 139/255, blue: 250/255)
private let mochiMint = Color(.sRGB, red: 94/255, green: 234/255, blue: 212/255)
private let mochiOrange = Color(.sRGB, red: 253/255, green: 186/255, blue: 116/255)

struct MochiRefreshActivityWidget: Widget
{
    var body: some WidgetConfiguration {
        if #available(iOSApplicationExtension 16.2, *)
        {
            return ActivityConfiguration(for: MochiRefreshAttributes.self) { context in
                MochiRefreshLockScreenView(state: context.state)
                    .activityBackgroundTint(mochiInk.opacity(0.85))
                    .activitySystemActionForegroundColor(.white)
            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        MochiCatIcon(size: 36)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Text(percentText(context.state))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(stateColor(context.state))
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(context.state.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            ProgressView(value: context.state.progress)
                                .tint(stateColor(context.state))
                        }
                    }
                } compactLeading: {
                    MochiCatIcon(size: 22)
                } compactTrailing: {
                    Text(percentText(context.state))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(stateColor(context.state))
                } minimal: {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: context.state.progress)
                            .stroke(stateColor(context.state), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(2)
                }
                .keylineTint(mochiLavender)
            }
        }
        else
        {
            return EmptyWidgetConfiguration()
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private func percentText(_ state: MochiRefreshAttributes.ContentState) -> String
{
    if state.isFinished { return state.didFail ? "!" : "✓" }
    return "\(Int((state.progress * 100).rounded()))%"
}

@available(iOSApplicationExtension 16.1, *)
private func stateColor(_ state: MochiRefreshAttributes.ContentState) -> Color
{
    if state.didFail { return mochiOrange }
    if state.isFinished { return mochiMint }
    return mochiLavender
}

private struct MochiCatIcon: View
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
private struct MochiRefreshLockScreenView: View
{
    let state: MochiRefreshAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            MochiCatIcon(size: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(percentText(state))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(stateColor(state))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: [mochiDeep, stateColor(state)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geometry.size.width * state.progress, 8))
                    }
                }
                .frame(height: 8)

                Text(state.detail)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

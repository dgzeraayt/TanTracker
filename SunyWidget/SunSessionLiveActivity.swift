import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity « Sun exposure » (bannière noire écran verrouillé + Dynamic Island)
@available(iOS 16.1, *)
struct SunSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunSessionAttributes.self) { context in
            LockScreenLiveView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Soleil", systemImage: "sun.max.fill")
                        .font(.caption).foregroundStyle(WPalette.amber)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("UV \(Int(context.attributes.uvIndex.rounded()))")
                        .font(.caption.bold()).foregroundStyle(WPalette.amber)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.phase == .reached {
                        Text("Couvre-toi — seuil atteint")
                            .font(.headline).foregroundStyle(WPalette.terra)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            timerText(context.state, big: true)
                            Text("avant le coup de soleil").font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill").foregroundStyle(WPalette.amber)
            } compactTrailing: {
                if context.state.phase == .reached {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(WPalette.terra)
                } else {
                    timerText(context.state, big: false).frame(width: 46)
                }
            } minimal: {
                Image(systemName: "sun.max.fill").foregroundStyle(WPalette.amber)
            }
            .widgetURL(URL(string: "suny://uv"))
        }
    }

    // Compte à rebours natif (auto-actualisé) vers le seuil de risque.
    @ViewBuilder
    private func timerText(_ state: SunSessionAttributes.ContentState, big: Bool) -> some View {
        let end = max(state.endDate, Date().addingTimeInterval(1))
        Group {
            if state.phase == .paused {
                Text("En pause")
            } else {
                Text(timerInterval: Date()...end, countsDown: true)
            }
        }
        .font(big ? .title2.bold() : .callout.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(.white)
    }
}

// MARK: - Vue écran verrouillé (bannière noire)
@available(iOS 16.1, *)
struct LockScreenLiveView: View {
    let attributes: SunSessionAttributes
    let state: SunSessionAttributes.ContentState

    private var startDate: Date {
        state.endDate.addingTimeInterval(-Double(attributes.safeMinutes) * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").foregroundStyle(WPalette.amber)
                Text("Exposition au soleil").font(.subheadline.bold()).foregroundStyle(WPalette.amber)
                Spacer(minLength: 4)
                Label(attributes.city, systemImage: "location.fill")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                    .labelStyle(.titleAndIcon)
                Text("UV \(Int(attributes.uvIndex.rounded()))")
                    .font(.caption.bold()).foregroundStyle(WPalette.amber)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }

            // Compte à rebours
            if state.phase == .reached {
                Label("Couvre-toi — seuil de risque atteint", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3.bold()).foregroundStyle(.white)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Group {
                        if state.phase == .paused {
                            Text("En pause")
                        } else {
                            Text(timerInterval: Date()...max(state.endDate, Date().addingTimeInterval(1)),
                                 countsDown: true)
                        }
                    }
                    .font(.system(size: 34, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
                    Text("avant le coup de soleil").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    Spacer(minLength: 0)
                }
            }

            // Progression + horaires
            VStack(spacing: 4) {
                ProgressView(value: min(1, max(0, state.progress)))
                    .tint(WPalette.amber)
                HStack {
                    Text(startDate, style: .time).font(.caption2).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(state.endDate, style: .time).font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
    }
}

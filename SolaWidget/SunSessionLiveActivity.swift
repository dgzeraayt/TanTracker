import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity « Sun exposure »
// Écran verrouillé + Dynamic Island. Cohérence de marque via WidgetPalette.
// État final `reached` : « Seuil atteint — couvre-toi ». Jamais d'incitation
// à prolonger l'exposition.

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct SunSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunSessionAttributes.self) { context in
            // — Écran verrouillé / bannière —
            LockScreenLiveActivityView(context: context)
                .widgetBackground(WidgetPalette.bg)
        } dynamicIsland: { context in
            dynamicIsland(context: context)
        }
    }

    @available(iOS 16.1, *)
    private func dynamicIsland(context: ActivityViewContext<SunSessionAttributes>)
        -> DynamicIsland {
        let reached = context.state.phase == .reached
        return DynamicIsland {
            // — Région étendue —
            DynamicIslandExpandedRegion(.leading) {
                Label {
                    Text(context.attributes.city).font(.system(size: 13, weight: .semibold))
                } icon: {
                    Image(systemName: "location.fill")
                }
                .foregroundStyle(WidgetPalette.ink)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Text("UV \(context.attributes.uvIndex.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(WidgetPalette.uvColor(context.attributes.uvIndex))
            }
            DynamicIslandExpandedRegion(.bottom) {
                if reached {
                    Label("Seuil atteint — couvre-toi", systemImage: "umbrella.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WidgetPalette.amberDeep)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Avant risque de coup de soleil")
                                .font(.system(size: 11)).foregroundStyle(WidgetPalette.ink3)
                            Spacer()
                            Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundStyle(WidgetPalette.ink)
                                .frame(maxWidth: 64)
                        }
                        ProgressView(value: context.state.progress)
                            .tint(WidgetPalette.amberDeep)
                    }
                }
            }
        } compactLeading: {
            Image(systemName: reached ? "umbrella.fill" : "sun.max.fill")
                .foregroundStyle(WidgetPalette.amberDeep)
        } compactTrailing: {
            if reached {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WidgetPalette.amberDeep)
            } else {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(WidgetPalette.ink)
                    .frame(maxWidth: 44)
            }
        } minimal: {
            Image(systemName: reached ? "umbrella.fill" : "sun.max.fill")
                .foregroundStyle(WidgetPalette.amberDeep)
        }
    }
}

// MARK: - Vue écran verrouillé
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<SunSessionAttributes>

    private var reached: Bool { context.state.phase == .reached }
    private var paused: Bool { context.state.phase == .paused }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill").font(.system(size: 10))
                Text(context.attributes.city).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("UV \(context.attributes.uvIndex.formatted(.number.precision(.fractionLength(0...1)))) · dose \(context.attributes.safeMinutes) min")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WidgetPalette.uvColor(context.attributes.uvIndex))
            }
            .foregroundStyle(WidgetPalette.ink2)

            if reached {
                HStack(spacing: 10) {
                    Image(systemName: "umbrella.fill").font(.system(size: 22))
                        .foregroundStyle(WidgetPalette.amberDeep)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Seuil atteint").font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(WidgetPalette.ink)
                        Text("Mets-toi à l'ombre et couvre-toi.")
                            .font(.system(size: 12)).foregroundStyle(WidgetPalette.ink2)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(paused ? "En pause" : "Avant risque de coup de soleil")
                        .font(.system(size: 12)).foregroundStyle(WidgetPalette.ink3)
                    Spacer()
                    Text(timerInterval: Date()...context.state.endDate,
                         countsDown: true, showsHours: false)
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundStyle(WidgetPalette.ink)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                ProgressView(value: context.state.progress)
                    .tint(WidgetPalette.amberDeep)
            }
        }
        .padding(14)
    }
}
#endif

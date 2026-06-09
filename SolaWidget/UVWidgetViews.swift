import WidgetKit
import SwiftUI

// MARK: - Briques visuelles communes

/// Mini-barre de l'échelle UV avec curseur sur la valeur courante.
struct UVMiniBar: View {
    let uv: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.uvGradient).frame(height: height)
                Circle().fill(.white)
                    .overlay(Circle().stroke(WidgetPalette.ink, lineWidth: 2))
                    .frame(width: height + 5, height: height + 5)
                    .offset(x: geo.size.width * min(1, max(0, uv / 11)) - (height + 5) / 2)
            }
        }
        .frame(height: height + 5)
    }
}

/// En-tête : localisation + libellé de niveau.
struct UVHeader: View {
    let city: String
    let level: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill").font(.system(size: 9))
            Text(city).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetPalette.ink2)
    }
}

/// État "données indisponibles".
struct UVUnavailable: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.system(size: 22)).foregroundStyle(WidgetPalette.amberDeep)
            Text("Ouvre SOLA").font(.system(size: 12, weight: .semibold)).foregroundStyle(WidgetPalette.ink)
            Text("pour les UV").font(.system(size: 10)).foregroundStyle(WidgetPalette.ink3)
        }
    }
}

// MARK: - Petit / Moyen
struct UVSmallMediumView: View {
    let entry: UVEntry
    var body: some View {
        if entry.unavailable {
            UVUnavailable()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                UVHeader(city: entry.data.city, level: entry.data.levelLabel)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.data.current.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.ink)
                    Text(entry.data.levelLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WidgetPalette.uvColor(entry.data.current))
                    Spacer(minLength: 0)
                }
                UVMiniBar(uv: entry.data.current)
                HStack {
                    Text("UV actuel").font(.system(size: 10)).foregroundStyle(WidgetPalette.ink3)
                    Spacer()
                    Text("Pic \(entry.data.peak.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WidgetPalette.ink2)
                }
                if entry.stale {
                    Text("Donnée à actualiser").font(.system(size: 9)).foregroundStyle(WidgetPalette.ink3)
                }
            }
        }
    }
}

// MARK: - Large (+ prévision 7 jours)
struct UVLargeView: View {
    let entry: UVEntry
    var body: some View {
        if entry.unavailable {
            UVUnavailable()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                UVHeader(city: entry.data.city, level: entry.data.levelLabel)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.data.current.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetPalette.ink)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.data.levelLabel).font(.system(size: 14, weight: .bold))
                            .foregroundStyle(WidgetPalette.uvColor(entry.data.current))
                        Text("Pic \(entry.data.peak.formatted(.number.precision(.fractionLength(0...1))))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(WidgetPalette.ink2)
                    }
                    Spacer(minLength: 0)
                }
                UVMiniBar(uv: entry.data.current)

                Divider()

                // Prévision 7 jours
                if entry.data.forecast.count > 1 {
                    HStack(spacing: 0) {
                        ForEach(Array(entry.data.forecast.prefix(7).enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 4) {
                                Text(day.dayLabel).font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(WidgetPalette.ink3)
                                Image(systemName: day.weatherIcon == "sun" ? "sun.max.fill" : "cloud.sun.fill")
                                    .font(.system(size: 13)).foregroundStyle(WidgetPalette.amberDeep)
                                Text(day.value.formatted(.number.precision(.fractionLength(0...1))))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(WidgetPalette.uvColor(day.value))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(WidgetPalette.amberDeep)
                        Text("Fenêtre douce : \(entry.data.idealWindow)")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(WidgetPalette.ink2)
                    }
                }
            }
        }
    }
}

// MARK: - Accessory (écran de verrouillage)
struct UVAccessoryView: View {
    let entry: UVEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("UV").font(.system(size: 9, weight: .bold))
                    Text(entry.unavailable ? "—" : entry.data.current.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
            }
        case .accessoryInline:
            if entry.unavailable {
                Label("UV indisponible", systemImage: "sun.max")
            } else {
                Label("UV \(entry.data.current.formatted(.number.precision(.fractionLength(0...1)))) · \(entry.data.levelLabel)",
                      systemImage: "sun.max.fill")
            }
        default: // accessoryRectangular
            if entry.unavailable {
                Label("Ouvre SOLA pour les UV", systemImage: "sun.max")
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UV \(entry.data.current.formatted(.number.precision(.fractionLength(0...1)))) · \(entry.data.levelLabel)")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(entry.data.city) · Pic \(entry.data.peak.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.system(size: 11))
                }
            }
        }
    }
}

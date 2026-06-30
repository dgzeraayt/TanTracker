import SwiftUI

// MARK: - Heatmap Calendar (GitHub style)
struct HeatmapCalendar: View {
    @EnvironmentObject var store: AppStore
    let monthData: [(Date, Int)]  // (date, activityLevel 0-4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendrier d'activité")
                .font(SolaFont.body(14, weight: .semibold))
                .foregroundStyle(Palette.ink)

            VStack(spacing: 8) {
                // Day labels
                HStack(spacing: 4) {
                    ForEach(["L", "M", "M", "J", "V", "S", "D"], id: \.self) { day in
                        Text(day)
                            .font(SolaFont.mono(10, weight: .medium))
                            .foregroundStyle(Palette.ink3)
                            .frame(height: 20)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Heat grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(monthData.indices, id: \.self) { i in
                        let (date, level) = monthData[i]
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(heatmapColor(level))
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(SolaFont.mono(9, weight: .medium))
                                .foregroundStyle(level > 2 ? .white : Palette.ink3)
                        }
                        .frame(height: 28)
                    }
                }
            }
            .padding(12)
            .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.28))

            // Legend
            HStack(spacing: 8) {
                Text("Moins").font(SolaFont.body(10)).foregroundStyle(Palette.ink3)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(level))
                        .frame(width: 12, height: 12)
                }
                Text("Plus").font(SolaFont.body(10)).foregroundStyle(Palette.ink3)
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.tintAmber, tintOpacity: 0.44))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Palette.line.opacity(0.42), lineWidth: 1))
    }

    private func heatmapColor(_ level: Int) -> Color {
        switch level {
        case 0: return Palette.lineSoft
        case 1: return Color(oklch: 0.88, 0.10, 70)
        case 2: return Color(oklch: 0.80, 0.12, 60)
        case 3: return Palette.amberDeep
        default: return Palette.terra
        }
    }
}

// MARK: - Line Chart (Tan Progress)
struct LineChart: View {
    let dataPoints: [CGFloat]
    let labels: [String]
    var color: Color = Palette.amberDeep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    // Grid background
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Divider().opacity(0.3)
                            Spacer()
                        }
                    }

                    // Chart
                    if !dataPoints.isEmpty {
                        Canvas { context, size in
                            let maxValue = dataPoints.max() ?? 100
                            let minValue = dataPoints.min() ?? 0
                            let range = maxValue - minValue
                            let padding: CGFloat = 10

                            // Normalize points
                            let normalizedPoints = dataPoints.enumerated().map { index, point in
                                let normalized = range > 0 ? (point - minValue) / range : 0.5
                                return CGPoint(
                                    x: padding + CGFloat(index) * (size.width - 2 * padding) / CGFloat(max(1, dataPoints.count - 1)),
                                    y: size.height - (normalized * (size.height - 2 * padding) + padding)
                                )
                            }

                            // Draw line
                            if normalizedPoints.count > 1 {
                                var path = Path()
                                path.move(to: normalizedPoints[0])
                                for i in 1..<normalizedPoints.count {
                                    path.addLine(to: normalizedPoints[i])
                                }

                                context.stroke(
                                    path,
                                    with: .color(color),
                                    lineWidth: 2.5
                                )

                                // Fill under curve
                                var fillPath = path
                                fillPath.addLine(to: CGPoint(x: normalizedPoints.last?.x ?? 0, y: size.height))
                                fillPath.addLine(to: CGPoint(x: normalizedPoints.first?.x ?? 0, y: size.height))
                                fillPath.closeSubpath()

                                context.fill(
                                    fillPath,
                                    with: .color(color.opacity(0.15))
                                )
                            }

                            // Draw points
                            for point in normalizedPoints {
                                context.fill(
                                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                                    with: .color(color)
                                )
                            }
                        }
                    }
                }
            }
            .frame(height: 180)

            // X-axis labels
            HStack(spacing: 0) {
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i])
                        .font(SolaFont.mono(9))
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
    }
}

// MARK: - UV Index Forecast Chart
struct UVForecastChart: View {
    @EnvironmentObject var store: AppStore
    let uvHourly: [Double]  // 24 values
    let currentHour: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Indice UV par heure")
                    .font(SolaFont.body(14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Badge(text: "Aujourd'hui", style: .amber)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(uvHourly.enumerated()), id: \.offset) { hour, uv in
                    VStack(spacing: 0) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(uvColor(uv))
                            .frame(height: max(4, CGFloat(uv) * 8))

                        // Current marker
                        if hour == currentHour {
                            Icon(name: "sun", size: 10, stroke: 1.5)
                                .foregroundStyle(Palette.terra)
                                .padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)

            // Time scale
            HStack(spacing: 0) {
                Text("6h").font(SolaFont.mono(8)).foregroundStyle(Palette.ink3)
                Spacer()
                Text("12h").font(SolaFont.mono(8)).foregroundStyle(Palette.ink3)
                Spacer()
                Text("18h").font(SolaFont.mono(8)).foregroundStyle(Palette.ink3)
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.tintGold, tintOpacity: 0.44))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Palette.line.opacity(0.42), lineWidth: 1))
    }

    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3: return Palette.lineSoft
        case 3..<6: return Color(oklch: 0.80, 0.15, 70)
        case 6..<9: return Palette.amberDeep
        default: return Palette.alert
        }
    }
}

// MARK: - Skin Metrics Radar
struct SkinMetricsRadar: View {
    let metrics: SkinMetrics?
    let targetMetrics: SkinMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Métriques de peau")
                .font(SolaFont.body(14, weight: .semibold))
                .foregroundStyle(Palette.ink)

            if let m = metrics {
                VStack(spacing: 14) {
                    metricBar(label: "Teinte", value: m.tan, max: 100, color: Palette.terra)
                    metricBar(label: "Éclat", value: m.glow, max: 100, color: Palette.amberDeep)
                    metricBar(label: "Uniformité", value: m.evenness, max: 100, color: Palette.gold)
                    metricBar(label: "Rougeur", value: m.redness, max: 100, color: Palette.alert)
                }
            } else {
                Text("Aucune analyse disponible")
                    .font(SolaFont.body(13))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.30))
    }

    private func metricBar(label: LocalizedStringKey, value: Int, max: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(value)%").font(SolaFont.display(16, weight: .bold)).foregroundStyle(color)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.lineSoft).frame(height: 8)
                Capsule().fill(color).frame(width: CGFloat(value) / CGFloat(max) * 100, height: 8)
            }
        }
    }
}

// MARK: - Analytics Dashboard
struct AnalyticsDashboard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var forecastStore: ForecastStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: TimePeriod = .week

    enum TimePeriod { case week, month, threeMonths }

    private var monthHeatmap: [(Date, Int)] {
        let cal = Calendar.current
        var data: [(Date, Int)] = []
        for i in 0..<30 {
            let date = cal.date(byAdding: .day, value: -i, to: .now)!
            let sessions = store.data.sessions.filter { cal.isDate($0.date, inSameDayAs: date) }
            let level = min(4, sessions.count)
            data.append((date, level))
        }
        return data.reversed()
    }

    // Vraie prévision UV du jour (source unique), répartie sur 24 créneaux horaires.
    // forecast.hourly ne couvre que les heures de jour (ex. 8h–16h) : les autres
    // créneaux restent à 0, ce qui est fidèle (pas d'UV la nuit).
    private var uvForecast: [Double] {
        var arr = [Double](repeating: 0, count: 24)
        for h in forecastStore.forecast.hourly {
            if let n = Int(h.hour.replacingOccurrences(of: "h", with: "")), (0..<24).contains(n) {
                arr[n] = h.uv
            }
        }
        return arr
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconButton(icon: "chevL", iconSize: 20) { dismiss() }
                        ScreenTitle(text: "Statistiques")
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Quick stats
                    HStack(spacing: 12) {
                        statCard(icon: "sun", value: "\(store.data.totalExposureMinutes)", label: "Min d'exposition")
                        statCard(icon: "fire", value: "\(store.streak)", label: "Jours de suite")
                        statCard(icon: "check", value: "\(store.data.completedRoutines)", label: "Routines")
                    }
                    .padding(.top, 20)

                    // Line chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Évolution de la teinte")
                            .font(SolaFont.body(14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        LineChart(
                            dataPoints: store.weeklySeries.map { CGFloat($0) },
                            labels: ["L-7", "L-6", "L-5", "L-4", "L-3", "L-2", "Auj"],
                            color: Palette.terra
                        )
                    }
                    .padding(.top, 14)

                    // Heatmap
                    HeatmapCalendar(monthData: monthHeatmap)
                        .padding(.top, 14)

                    // UV Forecast
                    UVForecastChart(uvHourly: uvForecast, currentHour: Calendar.current.component(.hour, from: .now))
                        .padding(.top, 14)

                    // Skin metrics
                    SkinMetricsRadar(metrics: store.latestMetrics, targetMetrics: nil)
                        .padding(.top, 14)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .task {
            await forecastStore.loadIfNeeded(lat: store.profile.latitude,
                                             lon: store.profile.longitude,
                                             city: store.profile.city)
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Icon(name: icon, size: 20).foregroundStyle(Palette.terra)
            Text(value).font(SolaFont.display(20, weight: .bold)).foregroundStyle(Palette.ink)
            Text(label).font(SolaFont.body(11)).foregroundStyle(Palette.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
    }
}

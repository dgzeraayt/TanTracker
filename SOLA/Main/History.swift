import SwiftUI

// MARK: - Before-After Slider
struct BeforeAfterSlider: View {
    @State private var sliderValue: CGFloat = 0.5
    let beforeImage: UIImage?
    let afterImage: UIImage?
    var beforeDate: Date = Date()
    var afterDate: Date = Date()

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // After image (background)
                    if let img = afterImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        StripedPlaceholder(tone: .deep)
                    }

                    // Before image (overlay with mask)
                    if let img = beforeImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .mask(
                                HStack(spacing: 0) {
                                    Color.white
                                    Color.clear
                                }
                                .offset(x: -(geo.size.width * (1 - sliderValue)))
                            )
                    }

                    // Slider handle
                    VStack {
                        Icon(name: "chevL", size: 12)
                        Icon(name: "chevR", size: 12)
                    }
                    .frame(width: 40, height: 60)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(4)
                    .offset(x: geo.size.width * sliderValue - 20)

                    // Interactive area
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = value.location.x / geo.size.width
                                    sliderValue = max(0, min(1, newValue))
                                }
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .frame(height: 300)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

            // Date labels
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avant").font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                    Text(beforeDate.formatted(date: .abbreviated, time: .omitted))
                        .font(SolaFont.body(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Après").font(SolaFont.mono(10)).foregroundStyle(Palette.ink3)
                    Text(afterDate.formatted(date: .abbreviated, time: .omitted))
                        .font(SolaFont.body(13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
    }
}

// MARK: - Photo Timeline Card
struct PhotoTimelineCard: View {
    let session: TanSession
    var photo: UIImage?
    var metrics: SkinMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(SolaFont.body(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    if let m = metrics {
                        HStack(spacing: 8) {
                            Badge(text: "Niv. \(m.tanLevel)", style: .amber)
                            Text("Éclat: \(m.glow)%")
                                .font(SolaFont.mono(11))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                }
                Spacer()
                if let m = metrics {
                    VStack(alignment: .trailing, spacing: 4) {
                        Icon(name: "drop", size: 20).foregroundStyle(Palette.terra)
                        Text("\(m.tanLevel)")
                            .font(SolaFont.display(18, weight: .bold))
                            .foregroundStyle(Palette.terra)
                    }
                }
            }

            if let img = photo {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
        }
        .padding(14)
        .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.32))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .stroke(Palette.line.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - Timeline View
struct PhotoTimeline: View {
    @EnvironmentObject var store: AppStore
    let sessions: [TanSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique de progression")
                .font(SolaFont.display(20, weight: .bold))
                .tracking(-0.3)
                .padding(.bottom, 14)

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Icon(name: "camera", size: 32).foregroundStyle(Palette.bronze)
                    Text("Aucune photo pour l'instant")
                        .font(SolaFont.body(15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Prends une photo pour commencer à tracker ta progression")
                        .font(SolaFont.body(13))
                        .foregroundStyle(Palette.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))
            } else {
                VStack(spacing: 12) {
                    ForEach(sessions.reversed()) { session in
                        let photo = session.photoFilename.flatMap { PhotoStore.load($0) }
                        PhotoTimelineCard(session: session, photo: photo, metrics: session.metrics)
                    }
                }
            }
        }
    }
}

// MARK: - Progress Chart (Tan Index Over Time)
struct ProgressChart: View {
    @EnvironmentObject var store: AppStore
    let weeklySeries: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Évolution de la teinte")
                    .font(SolaFont.body(14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("7 dernières semaines")
                    .font(SolaFont.mono(11))
                    .foregroundStyle(Palette.ink3)
            }

            BarsChart(values: weeklySeries, height: 140)
                .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Teinte moyenne")
                        .font(SolaFont.body(11))
                        .foregroundStyle(Palette.ink3)
                    let avg = Int(weeklySeries.reduce(0, +) / Double(max(1, weeklySeries.count)))
                    Text("\(avg)").font(SolaFont.display(24, weight: .bold)).foregroundStyle(Palette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Progression")
                        .font(SolaFont.body(11))
                        .foregroundStyle(Palette.ink3)
                    let progress = weeklySeries.last.map { Int($0) } ?? 0
                    let trend = progress - Int(weeklySeries.first ?? 0)
                    Text("\(trend > 0 ? "+" : "")\(trend)")
                        .font(SolaFont.display(24, weight: .bold))
                        .foregroundStyle(trend > 0 ? Palette.terra : Palette.ink3)
                }
            }
            .padding(12)
            .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.26))
        }
        .padding(16)
        .background(GlassPanel(radius: 18, tint: Palette.tintAmber, tintOpacity: 0.44))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Palette.line.opacity(0.42), lineWidth: 1))
    }
}

// MARK: - Full History Screen
struct EnhancedHistory: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedBefore: TanSession?
    @State private var selectedAfter: TanSession?

    private var photoSessions: [TanSession] {
        store.lastPhotoSessions
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        DisplayText(text: "Ma Progression", size: 38)
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Before-After Slider
                    if photoSessions.count >= 2,
                       let before = photoSessions.first,
                       let after = photoSessions.last,
                       let beforeImg = PhotoStore.load(before.photoFilename ?? ""),
                       let afterImg = PhotoStore.load(after.photoFilename ?? "") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Avant & Après")
                                .font(SolaFont.body(14, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            BeforeAfterSlider(
                                beforeImage: beforeImg,
                                afterImage: afterImg,
                                beforeDate: before.date,
                                afterDate: after.date
                            )
                        }
                        .padding(16)
                        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.32))
                        .padding(.top, 20)
                    }

                    // Progress Chart
                    ProgressChart(weeklySeries: store.weeklySeries)
                        .padding(.top, 14)

                    // Timeline
                    PhotoTimeline(sessions: photoSessions)
                        .padding(16)
                        .background(GlassPanel(radius: 18, tint: Palette.surface, tintOpacity: 0.28))
                        .padding(.top, 14)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
    }
}

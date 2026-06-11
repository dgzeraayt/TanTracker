import SwiftUI

// MARK: - Jauge circulaire (Indice de Bronzage)
struct Gauge: View {
    var value: Int = 69          // 0...100
    var size: CGFloat = 168
    var stroke: CGFloat = 16
    var label: String? = nil
    var sub: String? = nil
    var trackColor: Color = Palette.lineSoft
    var fillColor: Color = Palette.amberDeep

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: stroke))
            Circle()
                .trim(from: 0, to: CGFloat(value) / 100)
                .stroke(fillColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                (Text("\(value)").font(SolaFont.display(size * 0.30, weight: .heavy))
                    + Text("%").font(SolaFont.display(size * 0.13, weight: .heavy)))
                    .foregroundStyle(Palette.ink)
                if let label { Eyebrow(text: label) }
                if let sub {
                    Text(sub).font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Marque
struct SolaMark: View {
    var size: CGFloat = 30
    var color: Color = Palette.ink
    var body: some View {
        HStack(spacing: 10) {
            Icon(name: "sun", size: size, stroke: 2)
            Text("Suny")
                .font(SolaFont.display(size * 0.92, weight: .heavy))
                .tracking(2)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Placeholder rayé (motif du design quand pas d'image)
struct StripedPlaceholder: View {
    enum Tone { case base, warm, deep }
    var tone: Tone = .base

    private var colors: (Color, Color) {
        switch tone {
        case .base: return (Color(oklch: 0.86, 0.05, 64), Color(oklch: 0.89, 0.045, 70))
        case .warm: return (Color(oklch: 0.83, 0.07, 56), Color(oklch: 0.87, 0.06, 64))
        case .deep: return (Color(oklch: 0.62, 0.09, 52), Color(oklch: 0.66, 0.085, 58))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let (c1, c2) = colors
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(c1))
                // bandes diagonales à 135°
                let band: CGFloat = 11
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height + band, y: size.height))
                    p.addLine(to: CGPoint(x: x + band, y: 0))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(c2))
                    x += band * 2
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Illustration de marque (dégradé chaud + soleil) — remplace les photos stock
struct BrandArt: View {
    var tone: StripedPlaceholder.Tone = .base
    var seed: Int = 0

    private var grad: [Color] {
        switch tone {
        case .base: return [Color(oklch: 0.90, 0.06, 80), Color(oklch: 0.80, 0.10, 64)]
        case .warm: return [Color(oklch: 0.86, 0.10, 70), Color(oklch: 0.70, 0.13, 48)]
        case .deep: return [Color(oklch: 0.55, 0.12, 52), Color(oklch: 0.34, 0.07, 44)]
        }
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: grad, startPoint: .topLeading, endPoint: .bottomTrailing)
                // soleil doux décalé selon le seed
                let s = min(geo.size.width, geo.size.height)
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: s * 0.55))
                    .frame(width: s * 0.9, height: s * 0.9)
                    .offset(x: geo.size.width * (seed % 2 == 0 ? 0.18 : -0.2),
                            y: -geo.size.height * 0.18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

// Compat : image d'asset local avec fallback d'illustration de marque.
struct RemoteImage: View {
    var url: String = ""
    var tone: StripedPlaceholder.Tone = .base
    var body: some View {
        if url.isEmpty {
            BrandArt(tone: tone, seed: 0)
        } else {
            Image(url).resizable().scaledToFill()
        }
    }
}

// Identifiants d'images locales générées pour les écrans Suny.
enum IMG {
    static let faceFreckles = "sola_face_freckles"
    static let faceSmile    = "sola_face_analysis"
    static let faceSoft     = "sola_face_soft"
    static let facePortrait = "sola_face_scan"
    static let faceMan      = "sola_face_man"
    static let beach        = "sola_beach_uv_window"
    static let sunbathe     = "sola_sun_protected"
    static let shoulders    = "sola_tan_progress"
    static let coast        = "sola_coast_location"
    static let skincare     = "sola_skincare"
    static let position     = "sola_position"
    static let welcomeSunbathe = "sola_welcome_sunbathe"
}

// Identifiants des assets 3D clay générés pour l'onboarding.
enum ClayIMG {
    static let sun = "clay_sun"
    static let flame = "clay_flame"
    static let thermo = "clay_thermo"
    static let beach = "clay_beach"
    static let pool = "clay_pool"
    static let shield = "clay_shield"
    static let bell = "clay_bell"
    static let cloudSun = "clay_cloud_sun"
    static let cameraScan = "clay_camera_scan"
    static let timer = "clay_timer"
    static let mountain = "clay_mountain"
    static let leaf = "clay_leaf"
    static let skinPalette = "clay_skin_palette"
    static let freckles = "clay_freckles"

    static let eyes = ["clay_eye_blue", "clay_eye_green", "clay_eye_hazel", "clay_eye_brown"]
    static let hair = ["clay_hair_blond", "clay_hair_light_brown", "clay_hair_dark_brown", "clay_hair_black"]
    static let phototypes = [
        "clay_phototype_1", "clay_phototype_2", "clay_phototype_3",
        "clay_phototype_4", "clay_phototype_5", "clay_phototype_6"
    ]
}

struct ClayAssetImage: View {
    let name: String
    var size: CGFloat = 54
    var shadow: Bool = true

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: shadow ? Color(red: 0.31, green: 0.20, blue: 0.08).opacity(0.16) : .clear,
                    radius: shadow ? 8 : 0, x: 0, y: shadow ? 5 : 0)
    }
}

struct ClayAssetTile: View {
    let name: String
    var size: CGFloat = 48
    var tile: CGFloat = 58
    var selected: Bool = false

    var body: some View {
        ClayAssetImage(name: name, size: size)
            .frame(width: tile, height: tile)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Palette.ink.opacity(0.95) : Palette.bgWarm.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? Palette.gold.opacity(0.55) : .white.opacity(0.55), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Ligne d'option (onboarding)
struct OptionRow: View {
    var icon: String? = nil
    var asset: String? = nil
    let title: String
    var sub: String? = nil
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 15) {
            if let asset {
                ClayAssetTile(name: asset, size: 43, tile: 46, selected: selected)
            } else if let icon {
                Icon(name: icon, size: 21)
                    .foregroundStyle(selected ? Palette.gold : Palette.bronze)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(selected ? Palette.ink : Palette.bgWarm)
                    )
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(SolaFont.body(16, weight: .semibold)).foregroundStyle(Palette.ink)
                if let sub {
                    Text(sub).font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                }
            }
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(selected ? Palette.ink : Color.clear)
                    .overlay(Circle().stroke(selected ? Palette.ink : Palette.line, lineWidth: 2))
                    .frame(width: 24, height: 24)
                if selected { Icon(name: "check", size: 13, stroke: 2.6).foregroundStyle(.white) }
            }
        }
        .padding(.horizontal, 19).padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassPanel(radius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(selected ? Palette.ink : Color.clear, lineWidth: 1.5)
        )
    }
}

// Option "pill" en grille
struct PillOption<Top: View>: View {
    var selected: Bool = false
    let label: String
    @ViewBuilder var top: () -> Top

    var body: some View {
        VStack(spacing: 9) {
            top()
            Text(label)
                .font(SolaFont.body(14, weight: .semibold))
                .foregroundStyle(selected ? Palette.inkOn : Palette.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10).padding(.vertical, 18)
        .background(
            Group {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Palette.ink)
                } else {
                    GlassPanel(radius: Radius.md)
                }
            }
        )
    }
}

// MARK: - Graphique en barres (UV / évolution)
struct BarsChart: View {
    let values: [Double]      // 0...100
    var peakIndex: Int? = nil
    var height: CGFloat = 120

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(values.indices, id: \.self) { i in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5).fill(Palette.tintAmber)
                    GeometryReader { geo in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(i == peakIndex ? Palette.terra : Palette.amberDeep)
                                .frame(height: geo.size.height * values[i] / 100)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}

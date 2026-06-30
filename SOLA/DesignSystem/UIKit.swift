import SwiftUI

// Composants UI réutilisables — tous adossés aux tokens (Palette / Radius /
// Spacing / SolaFont). Aucune valeur de style en dur dans les écrans : ils
// passent par ces composants pour garantir la cohérence.

// MARK: - Titre d'écran (UN seul style partout)
struct ScreenTitle: View {
    let text: LocalizedStringKey
    var color: Color = Palette.ink
    var body: some View {
        Text(text)
            .font(SolaFont.screenTitle)
            .tracking(-0.5)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Label de section (overline mono capitales — rôle monospace autorisé)
struct SectionLabel: View {
    let text: LocalizedStringKey
    var color: Color = Palette.ink3
    var body: some View {
        Text(text)
            .font(SolaFont.sectionLabel)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Pill / Badge (variantes couleur respectant le contraste)
// Chaque variante définit un couple (fond, texte) au contraste vérifié.
// Fini le « FAIBLE ambre sur ambre » : le texte est toujours encre foncée
// sur tint clair, ou blanc sur fond saturé.
enum PillVariant {
    case neutral, accent, success, warning, alert
    case uv(Double)

    var bg: Color {
        switch self {
        case .neutral: return Palette.surface
        case .accent:  return Palette.accentSoft
        case .success: return Palette.success.opacity(0.16)
        case .warning: return Palette.warning.opacity(0.18)
        case .alert:   return Palette.alert.opacity(0.14)
        case .uv(let v): return Palette.uvColor(v).opacity(0.18)
        }
    }
    var fg: Color {
        switch self {
        case .neutral: return Palette.ink2
        case .accent:  return Palette.onAmber
        case .success: return Palette.success
        case .warning: return Color(oklch: 0.42, 0.12, 64) // ambre foncé lisible
        case .alert:   return Palette.alert
        case .uv(let v): return Palette.uvColorInk(v)
        }
    }
}

struct Pill: View {
    let text: LocalizedStringKey
    var icon: String? = nil
    var variant: PillVariant = .neutral
    /// Donnée chiffrée => police mono (rôle autorisé) ; sinon sans-serif.
    var isData: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Icon(name: icon, size: 13) }
            Text(text).textCase(.uppercase)
                .font(isData ? SolaFont.dataSmall : SolaFont.sectionLabel)
                .tracking(0.6)
        }
        .foregroundStyle(variant.fg)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .background(GlassPanel(radius: Radius.pill, tint: variant.bg, tintOpacity: 0.40, strokeOpacity: 0.52))
    }
}

// MARK: - Grand chiffre + label (donnée mise en avant)
struct StatNumber: View {
    let value: String
    let label: LocalizedStringKey
    var accent: Color = Palette.ink
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(SolaFont.dataLarge)
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(SolaFont.caption)
                .foregroundStyle(Palette.ink3)
        }
    }
}

// MARK: - Échelle UV (dégradé vert→rouge + curseur) — généralisée
struct UvScale: View {
    /// Position du curseur 0…1 (ex. uv/11). nil = pas de curseur.
    var position: Double?
    var height: CGFloat = 12
    var showLabels: Bool = false

    private let gradient = LinearGradient(
        colors: [Palette.uvLow, Palette.uvModerate, Palette.uvHigh, Palette.uvVeryHigh, Palette.uvExtreme],
        startPoint: .leading, endPoint: .trailing)

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(gradient).frame(height: height)
                    if let position {
                        Circle().fill(.white)
                            .overlay(Circle().stroke(Palette.ink, lineWidth: 3))
                            .frame(width: height + 8, height: height + 8)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                            .offset(x: geo.size.width * min(1, max(0, position)) - (height + 8) / 2)
                    }
                }
            }
            .frame(height: height + 8)
            if showLabels {
                HStack {
                    Text("FAIBLE"); Spacer(); Text("MODÉRÉ"); Spacer()
                    Text("ÉLEVÉ"); Spacer(); Text("EXTRÊME")
                }
                .font(SolaFont.dataSmall)
                .foregroundStyle(Palette.ink3)
            }
        }
    }
}

// MARK: - Ligne d'étape numérotée (Plan)
struct StepRow: View {
    let number: Int
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var meta: LocalizedStringKey? = nil
    var icon: String? = nil
    var done: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else { content }
        }
    }

    private var content: some View {
        CardBox(fill: done ? Palette.surface2 : Palette.surface, padding: Spacing.md, shadow: !done) {
            HStack(spacing: 14) {
                ZStack {
                    GlassCircle(tint: done ? Palette.ink : Palette.accentSoft,
                                tintOpacity: done ? 0.72 : 0.48)
                        .frame(width: 30, height: 30)
                    if done { Icon(name: "check", size: 15, stroke: 3).foregroundStyle(Palette.gold) }
                    else { Text("\(number)").font(SolaFont.dataSmall).foregroundStyle(Palette.bronze) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(SolaFont.cardTitle).foregroundStyle(Palette.ink)
                    Text(subtitle).font(SolaFont.caption).foregroundStyle(Palette.ink3)
                    if let meta {
                        HStack(spacing: 6) {
                            Icon(name: "clock", size: 13).foregroundStyle(Palette.amberDeep)
                            Text(meta).font(SolaFont.dataSmall).foregroundStyle(Palette.ink2)
                        }.padding(.top, 5)
                    }
                }
                Spacer(minLength: 0)
                if let icon {
                    Icon(name: icon, size: 20).foregroundStyle(Palette.bronze)
                        .frame(width: 42, height: 42)
                        .background(GlassPanel(radius: 13, tint: Palette.bgWarm, tintOpacity: 0.30))
                }
            }
            .opacity(done ? 0.72 : 1)
        }
    }
}

import SwiftUI

// MARK: - B1 · Bandeau « Dose du jour » (intégré à la carte héro de l'accueil)
// Jauge qui rapporte la dose UV cumulée au seuil sûr du phototype.
// Code couleur progressif (vert → orange → rouge) + message d'alerte ≥ 80 %.
struct DoseCard: View {
    let dose: ExposureDose

    private var tint: Color {
        switch dose.level {
        case .safe:    return Palette.success
        case .caution: return Palette.warning
        case .high:    return Palette.uvVeryHigh
        case .reached: return Palette.alert
        }
    }

    private var headline: String {
        switch dose.level {
        case .safe:    return "Tout va bien"
        case .caution: return "Lève un peu le pied"
        case .high:    return "Bientôt ta limite"
        case .reached: return "Stop pour aujourd'hui"
        }
    }

    private var message: String {
        switch dose.level {
        case .safe:
            return "Tu peux encore rester \(dose.remainingMinutes) min au soleil sans risque."
        case .caution:
            return "Encore \(dose.remainingMinutes) min de soleil possibles. Remets de la crème."
        case .high:
            return "Plus que \(dose.remainingMinutes) min avant le risque de coup de soleil."
        case .reached:
            return "Ta peau a eu assez de soleil. Reste à l'ombre — le bronzage continue."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionLabel(text: "Soleil reçu aujourd'hui")
                Spacer()
                Pill(text: "\(dose.percent) % de ta limite", variant: doseVariant, isData: true)
            }

            // Barre de progression de la dose
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.lineSoft)
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * min(1, dose.fraction))
                }
            }
            .frame(height: 8)

            HStack(spacing: 7) {
                Icon(name: dose.level == .reached ? "alertTri" : "shield", size: 13)
                    .foregroundStyle(tint)
                (Text(headline + " — ").font(SolaFont.body(12.5, weight: .bold))
                 + Text(message).font(SolaFont.caption))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var doseVariant: PillVariant {
        switch dose.level {
        case .safe:    return .success
        case .caution: return .warning
        case .high, .reached: return .alert
        }
    }
}

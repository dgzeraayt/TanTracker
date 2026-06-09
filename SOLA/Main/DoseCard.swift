import SwiftUI

// MARK: - B1 · Carte « Dose du jour »
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
        case .safe:    return "Dose sûre"
        case .caution: return "Surveille ta dose"
        case .high:    return "Approche du seuil"
        case .reached: return "Seuil atteint"
        }
    }

    private var message: String {
        switch dose.level {
        case .safe:
            return "Il te reste \(dose.remainingMinutes) min avant ton seuil sûr."
        case .caution:
            return "Encore \(dose.remainingMinutes) min disponibles. Pense à réappliquer ta crème."
        case .high:
            return "Plus que \(dose.remainingMinutes) min. Prépare-toi à te couvrir."
        case .reached:
            return "Tu as atteint ta dose sûre du jour. Mets-toi à l'ombre et couvre-toi."
        }
    }

    var body: some View {
        CardBox(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "Dose du jour")
                    Spacer()
                    Pill(text: "\(dose.percent) %", variant: doseVariant, isData: true)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headline)
                        .font(SolaFont.cardTitle)
                        .foregroundStyle(Palette.ink)
                }

                // Barre de progression de la dose
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.lineSoft)
                        Capsule().fill(tint)
                            .frame(width: geo.size.width * min(1, dose.fraction))
                    }
                }
                .frame(height: 10)

                HStack(spacing: 8) {
                    Icon(name: dose.level == .reached ? "alertTri" : "shield", size: 14)
                        .foregroundStyle(tint)
                    Text(message)
                        .font(SolaFont.caption)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

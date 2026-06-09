import SwiftUI

// MARK: - B3 · Carte de coaching contextuel
struct CoachCard: View {
    let message: CoachMessage

    private var tint: Color {
        switch message.tone {
        case .neutral:  return Palette.bronze
        case .positive: return Palette.success
        case .caution:  return Palette.warning
        case .alert:    return Palette.alert
        }
    }

    private var icon: String {
        switch message.tone {
        case .neutral:  return "cloudSun"
        case .positive: return "sun"
        case .caution:  return "shield"
        case .alert:    return "alertTri"
        }
    }

    var body: some View {
        CardBox(fill: Palette.ink, padding: 15) {
            HStack(alignment: .top, spacing: 12) {
                Icon(name: icon, size: 18).foregroundStyle(tint).padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.headline)
                        .font(SolaFont.body(14.5, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message.detail)
                        .font(SolaFont.caption)
                        .foregroundStyle(Color(red: 1, green: 0.94, blue: 0.86).opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

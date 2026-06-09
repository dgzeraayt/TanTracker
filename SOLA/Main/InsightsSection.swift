import SwiftUI

// MARK: - B4 · Section insights (mémoire)
struct InsightsSection: View {
    let insights: [Insight]

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Ce que dit ton historique")
                ForEach(insights) { insight in
                    CardBox(padding: 14, shadow: false, borderColor: Palette.lineSoft) {
                        HStack(alignment: .top, spacing: 14) {
                            Icon(name: insight.icon, size: 18).foregroundStyle(Palette.bronze)
                                .frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.accentSoft))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.title).font(SolaFont.cardTitle).foregroundStyle(Palette.ink)
                                Text(insight.detail).font(SolaFont.caption).foregroundStyle(Palette.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}

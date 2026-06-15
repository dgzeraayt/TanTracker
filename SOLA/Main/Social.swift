import SwiftUI

struct ShareProgressionCard: View {
    @EnvironmentObject var store: AppStore
    let tanLevel: Int
    let streak: Int
    let progressPercent: Int

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                SolaMark(size: 24)
                Spacer()
                Text("Goldn • Bronzage Sûr")
                    .font(SolaFont.mono(10))
                    .tracking(0.7)
                    .foregroundStyle(Palette.ink3)
            }

            // Main stats
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ma teinte").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                        Text("Niveau \(tanLevel)")
                            .font(SolaFont.display(28, weight: .bold))
                            .foregroundStyle(Palette.terra)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ma série").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                        HStack(spacing: 4) {
                            Icon(name: "fire", size: 18).foregroundStyle(Color(oklch: 0.72, 0.16, 32))
                            Text("\(streak) jours")
                                .font(SolaFont.display(24, weight: .bold))
                                .foregroundStyle(Color(oklch: 0.72, 0.16, 32))
                        }
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Plan: \(progressPercent)%").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    Track(value: Double(progressPercent) / 100.0, height: 8, fill: Palette.amberDeep)
                }
            }
            .padding(16)
            .background(GlassPanel(radius: Radius.md, tint: Palette.surface, tintOpacity: 0.30))

            // CTA
            Text("Rejins-moi sur Goldn pour un bronzage en toute sécurité ☀️")
                .font(SolaFont.body(13))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(GlassPanel(radius: 20, tint: Palette.tintGold, tintOpacity: 0.50))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Palette.amberDeep.opacity(0.3), lineWidth: 1.5))
    }
}

// MARK: - Share Sheet
struct ShareProgressionSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showCopyConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Partage ta progression")
                    .font(SolaFont.display(18, weight: .bold))
                    .tracking(-0.3)
                Spacer()
                Button(action: { dismiss() }) {
                    Icon(name: "x", size: 20).foregroundStyle(Palette.ink)
                }
            }
            .padding(.bottom, 8)

            ShareProgressionCard(
                tanLevel: store.tanLevel,
                streak: store.streak,
                progressPercent: Int(store.planProgress * 100)
            )

            VStack(spacing: 10) {
                Button(action: { shareAsScreenshot() }) {
                    HStack(spacing: 10) {
                        Icon(name: "share", size: 18).foregroundStyle(.white)
                        Text("Partager")
                            .font(SolaFont.body(14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(GlassPanel(radius: Radius.pill, tint: Palette.amberDeep, tintOpacity: 0.64))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { copyToClipboard() }) {
                    HStack(spacing: 10) {
                        Icon(name: "copy", size: 18).foregroundStyle(Palette.ink)
                        Text("Copier le lien")
                            .font(SolaFont.body(14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(GlassPanel(radius: Radius.pill, tint: Palette.surface, tintOpacity: 0.30))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(20)
        .background(Palette.bg)
    }

    private func shareAsScreenshot() {
        HapticsManager.shared.success()
        // Simulate sharing (in real app, render view to image and share)
        UIPasteboard.general.string = "Je suis \(store.profile.firstName) sur Goldn! Ma teinte est au niveau \(store.tanLevel) et j'ai une série de \(store.streak) jours! 🌞"
    }

    private func copyToClipboard() {
        HapticsManager.shared.tap()
        UIPasteboard.general.string = "Je bronze en toute sécurité avec Goldn! Rejoins-moi: goldnapp.com/\(store.profile.name.lowercased().replacingOccurrences(of: " ", with: ""))"
        showCopyConfirm = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyConfirm = false
        }
    }
}

import SwiftUI

// MARK: - Social Models
struct SocialChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let targetValue: Int
    let currentValue: Int
    let duration: String
    var participants: Int = 1
}

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
                Text("Suny • Bronzage Sûr")
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
            .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Palette.surface))

            // CTA
            Text("Rejins-moi sur Suny pour un bronzage en toute sécurité ☀️")
                .font(SolaFont.body(13))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Palette.tintGold, Palette.tintAmber],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .background(Palette.amberDeep)
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
                    .background(Palette.surface)
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
        UIPasteboard.general.string = "Je suis \(store.profile.firstName) sur Suny! Ma teinte est au niveau \(store.tanLevel) et j'ai une série de \(store.streak) jours! 🌞"
    }

    private func copyToClipboard() {
        HapticsManager.shared.tap()
        UIPasteboard.general.string = "Je bronze en toute sécurité avec Suny! Rejoins-moi: suny.app/\(store.profile.name.lowercased().replacingOccurrences(of: " ", with: ""))"
        showCopyConfirm = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyConfirm = false
        }
    }
}

// MARK: - Challenges View
struct AppChallenges: View {
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        ScreenTitle(text: "Défis")
                        Spacer()
                    }
                    .padding(.top, 4)

                    ChallengesView()
                        .padding(.top, 20)

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
    }
}

struct ChallengesView: View {
    @State private var selectedChallenge: SocialChallenge?
    let challenges: [SocialChallenge] = [
        SocialChallenge(
            id: "challenge_7days",
            title: "Série des 7 jours",
            description: "Maintiens une série de 7 jours consécutifs",
            icon: "fire",
            targetValue: 7,
            currentValue: 3,
            duration: "7 jours restants",
            participants: 234
        ),
        SocialChallenge(
            id: "challenge_100min",
            title: "100 minutes d'exposition",
            description: "Cumule 100 minutes d'exposition sûre",
            icon: "sun",
            targetValue: 100,
            currentValue: 65,
            duration: "14 jours restants",
            participants: 456
        ),
        SocialChallenge(
            id: "challenge_routine",
            title: "Routine complète",
            description: "Complète ta routine 5 jours de suite",
            icon: "check",
            targetValue: 5,
            currentValue: 2,
            duration: "5 jours restants",
            participants: 189
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Défis du moment")
                    .font(SolaFont.display(18, weight: .bold))
                    .tracking(-0.3)
                Spacer()
                Badge(text: "\(challenges.count) défis", style: .amber)
            }
            .padding(.bottom, 4)

            VStack(spacing: 10) {
                ForEach(challenges) { challenge in
                    ChallengeCard(challenge: challenge)
                        .onTapGesture { selectedChallenge = challenge }
                }
            }
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailSheet(challenge: challenge)
        }
    }
}

struct ChallengeCard: View {
    let challenge: SocialChallenge
    var progress: Double { Double(challenge.currentValue) / Double(challenge.targetValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Icon(name: challenge.icon, size: 24)
                    .foregroundStyle(Palette.amberDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(SolaFont.body(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(challenge.description)
                        .font(SolaFont.body(12))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(challenge.currentValue)/\(challenge.targetValue)")
                        .font(SolaFont.display(16, weight: .bold))
                        .foregroundStyle(Palette.terra)
                    Text(challenge.duration)
                        .font(SolaFont.mono(10))
                        .foregroundStyle(Palette.ink3)
                }
            }

            Track(value: progress, height: 6, fill: Palette.terra)

            HStack(spacing: 8) {
                Icon(name: "users", size: 14).foregroundStyle(Palette.bronze)
                Text("\(challenge.participants) participants")
                    .font(SolaFont.body(11))
                    .foregroundStyle(Palette.ink3)
                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .stroke(Palette.line, lineWidth: 1))
    }
}

struct ChallengeDetailSheet: View {
    let challenge: SocialChallenge
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Icon(name: "arrowL", size: 22).foregroundStyle(Palette.ink)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Icon(name: challenge.icon, size: 40)
                        .foregroundStyle(Palette.amberDeep)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Palette.tintAmber))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(SolaFont.display(20, weight: .bold))
                            .tracking(-0.3)
                            .foregroundStyle(Palette.ink)
                        Text(challenge.description)
                            .font(SolaFont.body(13))
                            .foregroundStyle(Palette.ink3)
                    }
                }

                // Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progression").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(challenge.currentValue)/\(challenge.targetValue)")
                            .font(SolaFont.display(16, weight: .bold))
                            .foregroundStyle(Palette.terra)
                    }
                    Track(value: Double(challenge.currentValue) / Double(challenge.targetValue), height: 8, fill: Palette.terra)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Palette.surface))

                // Stats
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Durée").font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
                        Text(challenge.duration).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Palette.surface)
                    .cornerRadius(Radius.md)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Participants").font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
                        Text("\(challenge.participants)").font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Palette.surface)
                    .cornerRadius(Radius.md)
                }

                Spacer()

                SolaButton(title: "Accepter le défi", kind: .amber, isCTA: true) {
                    HapticsManager.shared.celebration()
                }
            }
            .padding(16)
        }
        .padding(20)
        .background(Palette.bg)
    }
}

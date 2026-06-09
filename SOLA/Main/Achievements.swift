import SwiftUI

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    var size: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            Icon(name: achievement.icon, size: size * 0.4)
                .foregroundStyle(achievement.isUnlocked ? .white : Palette.ink3)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        achievement.isUnlocked
                            ? categoryColor(achievement.category)
                            : Palette.lineSoft
                    )
                )

            VStack(spacing: 2) {
                Text(achievement.title)
                    .font(SolaFont.body(12, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? Palette.ink : Palette.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if achievement.isUnlocked {
                    Text("Débloqué ✓")
                        .font(SolaFont.mono(10))
                        .foregroundStyle(categoryColor(achievement.category))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(achievement.isUnlocked ? 1 : 0.5)
    }

    private func categoryColor(_ category: Achievement.AchievementCategory) -> Color {
        switch category {
        case .streak: return Color(oklch: 0.72, 0.16, 32)  // Red
        case .exposure: return Palette.amberDeep
        case .routine: return Palette.gold
        case .milestone: return Palette.terra
        case .social: return Color(oklch: 0.68, 0.15, 280)  // Blue
        }
    }
}

// MARK: - Streak Badge (Home Card)
struct StreakBadge: View {
    let streak: Int
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Icon(name: "fire", size: 20).foregroundStyle(Color(oklch: 0.72, 0.16, 32))
                Text("\(streak) jours")
                    .font(SolaFont.display(18, weight: .bold))
                    .foregroundStyle(Color(oklch: 0.72, 0.16, 32))
            }

            Text(isActive ? "Série active 🔥" : "Série brisée")
                .font(SolaFont.body(12))
                .foregroundStyle(isActive ? Color(oklch: 0.72, 0.16, 32) : Palette.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color(oklch: 0.72, 0.16, 32).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(Color(oklch: 0.72, 0.16, 32).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quick Stats Row (Next Achievements Preview)
struct NextAchievementsPreview: View {
    @EnvironmentObject var store: AppStore
    let nextAchievements: [Achievement]

    var body: some View {
        if !nextAchievements.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Icon(name: "star", size: 16).foregroundStyle(Palette.gold)
                    Text("PROCHAINES RÉCOMPENSES")
                        .font(SolaFont.mono(11)).tracking(0.7)
                        .foregroundStyle(Palette.gold)
                }

                VStack(spacing: 8) {
                    ForEach(nextAchievements) { achievement in
                        HStack(spacing: 12) {
                            Icon(name: achievement.icon, size: 18)
                                .foregroundStyle(categoryColor(achievement.category))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle().fill(categoryColor(achievement.category).opacity(0.15))
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(achievement.title)
                                    .font(SolaFont.body(13, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(achievement.description)
                                    .font(SolaFont.body(12))
                                    .foregroundStyle(Palette.ink3)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(categoryColor(achievement.category).opacity(0.08)))
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.gold.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.gold.opacity(0.2), lineWidth: 1)))
        }
    }

    private func categoryColor(_ category: Achievement.AchievementCategory) -> Color {
        switch category {
        case .streak: return Color(oklch: 0.72, 0.16, 32)
        case .exposure: return Palette.amberDeep
        case .routine: return Palette.gold
        case .milestone: return Palette.terra
        case .social: return Color(oklch: 0.68, 0.15, 280)
        }
    }
}

// MARK: - Full Achievements Screen
struct AppAchievements: View {
    @EnvironmentObject var store: AppStore
    @State private var showShare = false

    private var achievementsByCategory: [Achievement.AchievementCategory: [Achievement]] {
        let grouped = Dictionary(grouping: store.data.achievements) { $0.category }
        return grouped
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        DisplayText(text: "Récompenses", size: 38)
                        Spacer()
                        Button { showShare = true } label: {
                            Icon(name: "share", size: 20).foregroundStyle(Palette.ink)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Palette.surface))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // Streak card
                    StreakBadge(streak: store.streak, isActive: store.todayHasExposure)
                        .padding(.top, 20)

                    // Stats
                    HStack(spacing: 12) {
                        statBox(icon: "sun", value: "\(store.data.totalExposureMinutes)", label: "Min d'exposition")
                        statBox(icon: "check", value: "\(store.data.completedRoutines)", label: "Routines complètes")
                        statBox(icon: "drop", value: "Niv. \(store.currentTanIndex / 20 + 1)", label: "Teinte actuelle")
                    }
                    .padding(.top, 14)

                    // Achievements by category
                    ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
                        if let achievements = achievementsByCategory[category], !achievements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Icon(name: categoryIcon(category), size: 16)
                                        .foregroundStyle(categoryColor(category))
                                    Text(categoryTitle(category))
                                        .font(SolaFont.mono(11)).tracking(0.7)
                                        .foregroundStyle(categoryColor(category))
                                }

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(achievements) { achievement in
                                        AchievementCard(achievement: achievement, size: 70)
                                    }
                                }
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(categoryColor(category).opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(categoryColor(category).opacity(0.15), lineWidth: 1)))
                            .padding(.top, 14)
                        }
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .sheet(isPresented: $showShare) { ShareProgressionSheet() }
    }

    private func statBox(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Icon(name: icon, size: 18).foregroundStyle(Palette.bronze)
            Text(value).font(SolaFont.display(16, weight: .bold)).foregroundStyle(Palette.ink)
            Text(label).font(SolaFont.body(11)).foregroundStyle(Palette.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Palette.surface))
    }

    private func categoryTitle(_ category: Achievement.AchievementCategory) -> String {
        switch category {
        case .streak: return "Streaks"
        case .exposure: return "Exposition"
        case .routine: return "Routine"
        case .milestone: return "Jalons"
        case .social: return "Social"
        }
    }

    private func categoryIcon(_ category: Achievement.AchievementCategory) -> String {
        switch category {
        case .streak: return "fire"
        case .exposure: return "sun"
        case .routine: return "check"
        case .milestone: return "target"
        case .social: return "share"
        }
    }

    private func categoryColor(_ category: Achievement.AchievementCategory) -> Color {
        switch category {
        case .streak: return Color(oklch: 0.72, 0.16, 32)
        case .exposure: return Palette.amberDeep
        case .routine: return Palette.gold
        case .milestone: return Palette.terra
        case .social: return Color(oklch: 0.68, 0.15, 280)
        }
    }
}

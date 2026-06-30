import Foundation

// MARK: - Gamification System
struct Achievement: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    var unlockedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }

    enum AchievementCategory: String, Codable, CaseIterable {
        case streak = "streak"
        case exposure = "exposure"
        case routine = "routine"
        case milestone = "milestone"
        case social = "social"
    }
}

extension Achievement {
    static let allAchievements: [Achievement] = [
        // Streaks
        Achievement(id: "streak_3", title: String(localized: "Début Prometteur"), description: String(localized: "3 jours de suite"), icon: "fire", category: .streak),
        Achievement(id: "streak_7", title: String(localized: "Une Semaine !"), description: String(localized: "7 jours de suite"), icon: "flame", category: .streak),
        Achievement(id: "streak_30", title: String(localized: "Habitué"), description: String(localized: "30 jours de suite"), icon: "star", category: .streak),
        Achievement(id: "streak_100", title: String(localized: "Légendaire"), description: String(localized: "100 jours de suite"), icon: "crown", category: .streak),

        // Exposure
        Achievement(id: "expo_10min", title: String(localized: "Premiers Rayons"), description: String(localized: "10 min d'exposition"), icon: "sun", category: .exposure),
        Achievement(id: "expo_100min", title: String(localized: "Sous le Soleil"), description: String(localized: "100 min cumulées"), icon: "sunFull", category: .exposure),
        Achievement(id: "expo_1000min", title: String(localized: "Amoureux du Soleil"), description: String(localized: "1000 min cumulées"), icon: "sunBright", category: .exposure),

        // Routine
        Achievement(id: "routine_5complete", title: String(localized: "Routine Maître"), description: String(localized: "5 routines complètes"), icon: "check", category: .routine),
        Achievement(id: "routine_30complete", title: String(localized: "Discipliné"), description: String(localized: "30 routines complètes"), icon: "checkCircle", category: .routine),

        // Milestones
        Achievement(id: "milestone_tan3", title: String(localized: "Teinte Progressive"), description: String(localized: "Niveau 3 atteint"), icon: "drop", category: .milestone),
        Achievement(id: "milestone_tan5", title: String(localized: "Bronzage Ultime"), description: String(localized: "Niveau 5 atteint"), icon: "dropFull", category: .milestone),
        Achievement(id: "milestone_plan_complete", title: String(localized: "Plan Réussi"), description: String(localized: "Plan terminé avec succès"), icon: "target", category: .milestone),

        // Social (for future)
        Achievement(id: "social_share", title: String(localized: "Partager c'est Caring"), description: String(localized: "Partage ta progression"), icon: "share", category: .social),
    ]
}

// MARK: - Gamification State in AppData
extension AppData {
    var totalExposureMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var completedRoutines: Int {
        routineDays.filter { !$0.completed.isEmpty }.count
    }
}

// MARK: - Gamification Manager
extension AppStore {
    /// Check et unlock achievements basé sur l'état actuel
    func checkAndUnlockAchievements() {
        var updated = data.achievements
        let currentStreak = streak
        let totalExposure = data.totalExposureMinutes
        let completedRoutines = data.completedRoutines
        let currentTan = currentTanIndex

        // Streak achievements
        if currentStreak >= 3 { unlock(&updated, id: "streak_3") }
        if currentStreak >= 7 { unlock(&updated, id: "streak_7") }
        if currentStreak >= 30 { unlock(&updated, id: "streak_30") }
        if currentStreak >= 100 { unlock(&updated, id: "streak_100") }

        // Exposure achievements
        if totalExposure >= 10 { unlock(&updated, id: "expo_10min") }
        if totalExposure >= 100 { unlock(&updated, id: "expo_100min") }
        if totalExposure >= 1000 { unlock(&updated, id: "expo_1000min") }

        // Routine achievements
        if completedRoutines >= 5 { unlock(&updated, id: "routine_5complete") }
        if completedRoutines >= 30 { unlock(&updated, id: "routine_30complete") }

        // Milestone achievements
        if currentTan >= 65 { unlock(&updated, id: "milestone_tan3") }
        if currentTan >= 95 { unlock(&updated, id: "milestone_tan5") }

        data.achievements = updated
        saveNow()
    }

    private func unlock(_ achievements: inout [Achievement], id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return }
        if achievements[index].unlockedAt == nil {
            achievements[index].unlockedAt = .now
            HapticsManager.shared.celebration()
        }
    }

    var unlockedAchievements: [Achievement] {
        data.achievements.filter { $0.isUnlocked }
    }

    var nextAchievements: [Achievement] {
        data.achievements.filter { !$0.isUnlocked }.prefix(3).map { $0 }
    }
}

import SwiftUI

// MARK: - Coaching Context
struct CoachingContext {
    let phototype: Fitzpatrick
    let currentUVIndex: Double
    let timeOfDay: TimeOfDayContext
    let totalExposureToday: Int // minutes
    let dailyExposureGoal: Int // minutes
    let skinCondition: SkinCondition
    let lastExposureWas: Date?
    let consecutiveDays: Int
}

enum SkinCondition {
    case normal
    case sensitive
    case sunburned
    case veryDry
    case irritated
}

// MARK: - Coaching Tip Model
struct CoachingTip: Identifiable {
    let id = UUID()
    let category: TipCategory
    let title: String
    let message: String
    let icon: String
    let severity: TipSeverity
    let actionable: Bool
    let actionTitle: String?
    let contextReason: String
}

enum TipCategory {
    case exposure, protection, hydration, timing, recovery, warning, achievement
}

enum TipSeverity {
    case info, caution, warning, urgent

    var color: Color {
        switch self {
        case .info: return Palette.gold
        case .caution: return Palette.amberDeep
        case .warning: return Palette.alert
        case .urgent: return Palette.alert
        }
    }
}

// MARK: - Smart Coaching Engine
@MainActor
final class SmartCoachingEngine {
    static let shared = SmartCoachingEngine()

    // MARK: - Main Coaching Methods
    func generateExposureTips(context: CoachingContext) -> [CoachingTip] {
        var tips: [CoachingTip] = []

        // UV Index warnings
        if context.currentUVIndex >= 11 {
            tips.append(CoachingTip(
                category: .warning,
                title: "UV très élevé",
                message: "Les UV sont extrêmement intenses. Réduis ta durée d'exposition et applique SPF 50+.",
                icon: "alertTri",
                severity: .urgent,
                actionable: true,
                actionTitle: "Réduire la durée",
                contextReason: "Indice UV \(Int(context.currentUVIndex))"
            ))
        } else if context.currentUVIndex >= 8 {
            tips.append(CoachingTip(
                category: .warning,
                title: "UV élevé",
                message: "Les UV sont intenses. Sois prudent et réapplique SPF toutes les 2h.",
                icon: "sun",
                severity: .caution,
                actionable: false,
                actionTitle: nil,
                contextReason: "Indice UV \(Int(context.currentUVIndex))"
            ))
        }

        // Phototype-specific duration guidance
        let maxDuration = phototypeDuration(context.phototype, uvIndex: context.currentUVIndex)
        if context.totalExposureToday > maxDuration {
            tips.append(CoachingTip(
                category: .exposure,
                title: "Limite atteinte",
                message: "Tu as dépassé la durée recommandée pour ton phototype \(context.phototype.roman). Rentre à l'intérieur.",
                icon: "clock",
                severity: .warning,
                actionable: false,
                actionTitle: nil,
                contextReason: "Phototype \(context.phototype.roman): max \(maxDuration)min"
            ))
        }

        // Time-of-day guidance
        if context.timeOfDay == .afternoon || context.timeOfDay == .early {
            tips.append(CoachingTip(
                category: .timing,
                title: "Meilleure heure pour toi",
                message: "Le créneau 10h-13h est optimal. Les UV sont parfaits pour ton phototype.",
                icon: "sunFull",
                severity: .info,
                actionable: false,
                actionTitle: nil,
                contextReason: "Pics UV: 10h-13h"
            ))
        }

        // Reapplication reminder during exposure
        if context.totalExposureToday > 120 && context.totalExposureToday % 120 == 0 {
            tips.append(CoachingTip(
                category: .protection,
                title: "Réappliquer SPF",
                message: "Ça fait 2h. Réapplique ta crème solaire maintenant.",
                icon: "shield",
                severity: .caution,
                actionable: true,
                actionTitle: "Rappeler dans 2h",
                contextReason: "Toutes les 2h"
            ))
        }

        return tips
    }

    func generateProtectionTips(context: CoachingContext) -> [CoachingTip] {
        var tips: [CoachingTip] = []

        // Skin condition warnings
        if context.skinCondition == .sunburned {
            tips.append(CoachingTip(
                category: .warning,
                title: "Peau brûlée",
                message: "Ta peau est irritée. N'utilise que SPF 50+, hydrate régulièrement et évite les produits agressifs.",
                icon: "alertTri",
                severity: .urgent,
                actionable: true,
                actionTitle: "Mode récupération",
                contextReason: "Repos recommandé 2-3 jours"
            ))
        }

        if context.skinCondition == .sensitive {
            tips.append(CoachingTip(
                category: .protection,
                title: "Peau sensible",
                message: "Préfère un SPF 50 minéral et réapplique toutes les heures.",
                icon: "shield",
                severity: .caution,
                actionable: false,
                actionTitle: nil,
                contextReason: "Phototype \(context.phototype.roman)"
            ))
        }

        // SPF reminders based on time
        if context.currentUVIndex >= 6 {
            tips.append(CoachingTip(
                category: .protection,
                title: "Applique SPF maintenant",
                message: "Les UV sont suffisamment intenses. N'oublie pas 15 min avant de t'exposer.",
                icon: "shield",
                severity: .info,
                actionable: true,
                actionTitle: "Timer 15 min",
                contextReason: "Absorption cutanée: 15 min"
            ))
        }

        return tips
    }

    func generateHydrationTips(context: CoachingContext) -> [CoachingTip] {
        var tips: [CoachingTip] = []

        if context.currentUVIndex >= 8 {
            tips.append(CoachingTip(
                category: .hydration,
                title: "Hydrate toutes les heures",
                message: "Avec des UV intenses, hydrate-toi plus souvent (spray thermale toutes les 30-45 min).",
                icon: "drop",
                severity: .caution,
                actionable: false,
                actionTitle: nil,
                contextReason: "UV très élevé"
            ))
        } else {
            tips.append(CoachingTip(
                category: .hydration,
                title: "Hydrate toutes les 2h",
                message: "Garde ta peau fraîche avec une brumiste ou spray thermale.",
                icon: "drop",
                severity: .info,
                actionable: true,
                actionTitle: "Rappeler",
                contextReason: "Hydratation régulière"
            ))
        }

        return tips
    }

    func generateRecoveryTips(context: CoachingContext) -> [CoachingTip] {
        var tips: [CoachingTip] = []

        if context.timeOfDay == .evening {
            tips.append(CoachingTip(
                category: .recovery,
                title: "After-sun + Aloe vera",
                message: "Applique un soin after-sun riche. L'aloe vera aide à fixer le bronzage.",
                icon: "leaf",
                severity: .info,
                actionable: true,
                actionTitle: "Commencer les soins",
                contextReason: "Réparer le soir"
            ))
        }

        if context.skinCondition == .veryDry {
            tips.append(CoachingTip(
                category: .recovery,
                title: "Hydratation intensive",
                message: "Ta peau est déshydratée. Utilise un masque hydratant ce soir.",
                icon: "drop",
                severity: .caution,
                actionable: false,
                actionTitle: nil,
                contextReason: "Sécheresse détectée"
            ))
        }

        return tips
    }

    func generateAchievementTips(context: CoachingContext) -> [CoachingTip] {
        var tips: [CoachingTip] = []

        if context.consecutiveDays >= 7 && context.consecutiveDays % 7 == 0 {
            tips.append(CoachingTip(
                category: .achievement,
                title: "Série impressionnante!",
                message: "Tu es régulier depuis \(context.consecutiveDays) jours. Continue comme ça! 🔥",
                icon: "fire",
                severity: .info,
                actionable: false,
                actionTitle: nil,
                contextReason: "Constance récompensée"
            ))
        }

        if context.totalExposureToday >= context.dailyExposureGoal {
            tips.append(CoachingTip(
                category: .achievement,
                title: "Objectif atteint!",
                message: "Bravo! Tu as complété ton exposition du jour. Pense au after-sun ce soir.",
                icon: "check",
                severity: .info,
                actionable: true,
                actionTitle: "Voir les stats",
                contextReason: "Défi quotidien complété"
            ))
        }

        return tips
    }

    // MARK: - Context-Aware Step Coaching
    func generateStepCoaching(stepId: Int, context: CoachingContext) -> CoachingTip? {
        switch stepId {
        case 0: // Exposure
            if context.timeOfDay == .early {
                return CoachingTip(
                    category: .timing,
                    title: "Attends 10h si possible",
                    message: "C'est encore tôt. À 10h, les UV seront meilleurs pour ta teinte.",
                    icon: "sunrise",
                    severity: .info,
                    actionable: false,
                    actionTitle: nil,
                    contextReason: "Optimization horaire"
                )
            }

            if context.currentUVIndex < 3 {
                return CoachingTip(
                    category: .exposure,
                    title: "UV insuffisant",
                    message: "L'indice UV est bas. Augmente ta durée d'exposition (20-30 min).",
                    icon: "sun",
                    severity: .info,
                    actionable: false,
                    actionTitle: nil,
                    contextReason: "Faible UV: \(Int(context.currentUVIndex))"
                )
            }

        case 1: // SPF
            if context.currentUVIndex >= 10 {
                return CoachingTip(
                    category: .protection,
                    title: "SPF 50+ obligatoire",
                    message: "Les UV sont extrêmes. Utilise SPF 50+, pas SPF 30.",
                    icon: "shield",
                    severity: .warning,
                    actionable: false,
                    actionTitle: nil,
                    contextReason: "UV très élevé"
                )
            }

        case 2: // Hydration
            if context.skinCondition == .sensitive {
                return CoachingTip(
                    category: .hydration,
                    title: "Hydrate plus souvent",
                    message: "Ta peau est sensible. Utilise une eau thermale toutes les 30 min.",
                    icon: "drop",
                    severity: .caution,
                    actionable: false,
                    actionTitle: nil,
                    contextReason: "Peau sensible"
                )
            }

        case 3: // After-sun
            if context.skinCondition == .sunburned {
                return CoachingTip(
                    category: .recovery,
                    title: "Soin intensif ce soir",
                    message: "Ton after-sun doit être riche et apaisante. L'aloe vera pure si possible.",
                    icon: "leaf",
                    severity: .caution,
                    actionable: false,
                    actionTitle: nil,
                    contextReason: "Brûlure légère détectée"
                )
            }

        case 4: // Photo
            return CoachingTip(
                category: .exposure,
                title: "Même condition que d'habitude",
                message: "Prends la photo dans la même lumière (matin/après-midi) pour bien comparer.",
                icon: "camera",
                severity: .info,
                actionable: false,
                actionTitle: nil,
                contextReason: "Consistance de mesure"
            )

        default:
            return nil
        }

        return nil
    }

    // MARK: - Helper Methods
    private func phototypeDuration(_ phototype: Fitzpatrick, uvIndex: Double) -> Int {
        // Recommended max duration in minutes based on Fitzpatrick type
        let baseMinutes: Int
        switch phototype {
        case .I: baseMinutes = 10
        case .II: baseMinutes = 15
        case .III: baseMinutes = 20
        case .IV: baseMinutes = 25
        case .V: baseMinutes = 30
        case .VI: baseMinutes = 40
        }

        // Reduce based on UV index
        let uvFactor = max(0.3, 1.0 - (uvIndex / 15.0))
        return Int(Double(baseMinutes) * uvFactor)
    }
}

// MARK: - Coaching UI Component
struct SmartCoachingCard: View {
    let tip: CoachingTip
    var onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Icon(name: tip.icon, size: 24)
                    .foregroundStyle(tip.severity.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(SolaFont.body(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)

                    Text(tip.message)
                        .font(SolaFont.body(13))
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(3)
                }

                Spacer()
            }

            if let actionTitle = tip.actionTitle {
                Button(action: { onAction?() }) {
                    HStack(spacing: 6) {
                        Text(actionTitle)
                            .font(SolaFont.body(12, weight: .semibold))
                            .foregroundStyle(tip.severity.color)
                        Icon(name: "arrowR", size: 12).foregroundStyle(tip.severity.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(tip.severity.color.opacity(0.1))
                    .cornerRadius(Radius.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(tip.severity == .urgent ? Palette.alert.opacity(0.1) : Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(tip.severity.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CoachingTipsList: View {
    let tips: [CoachingTip]
    var onAction: ((CoachingTip) -> Void)?

    var body: some View {
        if tips.isEmpty {
            HStack(spacing: 8) {
                Icon(name: "check", size: 16).foregroundStyle(Palette.gold)
                Text("Tout va bien! Continue comme ça.")
                    .font(SolaFont.body(13))
                    .foregroundStyle(Palette.ink2)
                Spacer()
            }
            .padding(12)
            .background(Palette.gold.opacity(0.1))
            .cornerRadius(Radius.md)
        } else {
            VStack(spacing: 10) {
                ForEach(tips) { tip in
                    SmartCoachingCard(tip: tip) {
                        onAction?(tip)
                    }
                }
            }
        }
    }
}

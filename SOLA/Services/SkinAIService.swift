import Foundation

// MARK: - Générateur de conseil 100% on-device
// Aucune clé, aucun réseau, aucune donnée qui sort de l'appareil. Le conseil est
// composé à partir d'une large banque de phrases combinée selon les mesures
// (déterministes) et le profil. Le tirage est seedé par les mesures : un même scan
// donne toujours le même conseil (cohérent), des scans différents varient.
enum SkinAdvice {
    static func make(for m: SkinMetrics, profile: UserProfile) -> String {
        var pick = Picker(seed: seed(m, profile))
        let sit = situation(for: m, goal: profile.goal)

        var parts: [String] = [pick.choose(state(for: sit))]

        // Observation secondaire (éclat / uniformité) ~une fois sur deux, hors alerte.
        if sit != .burnAlert, pick.bit(), let obs = secondary(for: m) {
            parts.append(pick.choose(obs))
        }

        parts.append(pick.choose(action(for: sit, goal: profile.goal)))

        // Rappel de prudence pour les phototypes clairs (l'alerte le dit déjà).
        if profile.phototype.rawValue <= 2, sit == .fresh || sit == .building || sit == .onTarget, pick.bit() {
            parts.append(pick.choose(fairSkinReminder))
        }

        return parts.joined(separator: " ")
    }

    // MARK: Situation
    private enum Sit { case burnAlert, irritation, fresh, building, onTarget, deep }

    private static func situation(for m: SkinMetrics, goal: TanGoal) -> Sit {
        if m.redness >= 58 { return .burnAlert }
        if m.redness >= 38 { return .irritation }
        let target = goal.targetIndex
        if m.tan < 30 { return .fresh }
        if m.tan < target - 8 { return .building }
        if m.tan <= target + 6 { return .onTarget }
        return .deep
    }

    private static func state(for sit: Sit) -> [String] {
        switch sit {
        case .burnAlert:  return burnState
        case .irritation: return irritationState
        case .fresh:      return freshState
        case .building:   return buildingState
        case .onTarget:   return onTargetState
        case .deep:       return deepState
        }
    }

    private static func action(for sit: Sit, goal: TanGoal) -> [String] {
        switch sit {
        case .burnAlert:  return burnActions
        case .irritation: return irritationActions
        case .deep:       return maintainActions
        case .fresh, .building, .onTarget:
            switch goal {
            case .safe:       return safeActions
            case .maintain:   return maintainActions
            case .subtleGlow: return glowActions
            case .deepTan:    return deepTanActions
            }
        }
    }

    private static func secondary(for m: SkinMetrics) -> [String]? {
        var pool: [String] = []
        if m.glow >= 72 { pool += glowHigh } else if m.glow < 32 { pool += glowLow }
        if m.evenness >= 82 { pool += evenHigh } else if m.evenness < 45 { pool += evenLow }
        return pool.isEmpty ? nil : pool
    }

    // MARK: Tirage déterministe (xorshift seedé par les mesures)
    private struct Picker {
        private var s: UInt64
        init(seed: UInt64) { s = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        private mutating func next() -> UInt64 { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s }
        mutating func choose(_ a: [String]) -> String { a[Int(next() % UInt64(a.count))] }
        mutating func bit() -> Bool { next() & 1 == 0 }
    }

    private static func seed(_ m: SkinMetrics, _ p: UserProfile) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        let goalCode: Int = [.subtleGlow: 1, .deepTan: 2, .maintain: 3, .safe: 4][p.goal] ?? 0
        for v in [m.tan, m.glow, m.evenness, m.redness, p.phototype.rawValue, goalCode] {
            h = (h ^ UInt64(truncatingIfNeeded: v)) &* 1099511628211
        }
        return h
    }

    // MARK: - Banques de phrases

    private static let burnState = [
        "Ta peau est nettement échauffée : signe qu'elle a eu sa dose d'UV pour aujourd'hui.",
        "On voit des rougeurs marquées — ta peau te dit clairement stop.",
        "Rougeur élevée détectée : ta peau est en train de réagir aux UV.",
        "Ta peau montre des signes francs d'irritation après l'exposition.",
        "Le rouge domine : ta peau a été poussée un peu trop loin.",
        "Coup de chaud visible — la priorité passe à la récupération.",
        "Les rougeurs sont nettes : ta peau a besoin de souffler.",
        "Ta peau est échauffée et sensible aujourd'hui.",
        "Rougeur importante : ce n'est vraiment pas le moment d'en rajouter.",
        "Ta peau tire vers le rouge, elle a atteint sa limite du moment."
    ]

    private static let irritationState = [
        "Ta peau commence à rosir légèrement.",
        "On perçoit un soupçon de rougeur sur ta peau.",
        "Ta peau est un peu réactive aujourd'hui, sans excès.",
        "Légère chaleur visible : ta peau a bien reçu les UV.",
        "Un voile de rougeur apparaît, rien d'alarmant.",
        "Ta peau pointe une petite réaction aux UV.",
        "La teinte monte, avec un léger échauffement.",
        "Ta peau rosit doucement — à garder à l'œil."
    ]

    private static let freshState = [
        "Ta peau est encore très claire, tout est à construire.",
        "Point de départ tout en clarté : ton hâle ne fait que commencer.",
        "Ta peau est nette et claire, prête pour un bronzage progressif.",
        "Encore peu de hâle — c'est le tout début du parcours.",
        "Ta carnation est claire et reposée.",
        "Base claire : idéale pour bâtir un hâle en douceur.",
        "Côté bronzage tu pars de zéro, et c'est parfait pour bien faire.",
        "Teint clair et frais, sans signe de fatigue cutanée."
    ]

    private static let buildingState = [
        "Ton hâle s'installe joliment.",
        "La teinte progresse dans la bonne direction.",
        "Ton bronzage prend forme, étape par étape.",
        "Belle progression : ta peau se dore peu à peu.",
        "Le hâle monte régulièrement, sans à-coups.",
        "Ta peau gagne en couleur tout en restant saine.",
        "Tu es en bonne voie vers ta teinte cible.",
        "La couleur s'approfondit doucement.",
        "Ton bronzage avance à un bon rythme."
    ]

    private static let onTargetState = [
        "Tu y es presque : ta teinte approche ton objectif.",
        "Ton hâle est pile dans la zone que tu vises.",
        "Belle teinte, très proche de ta cible.",
        "Ta couleur correspond à ce que tu recherches.",
        "Objectif quasiment atteint, joli résultat.",
        "Ton bronzage est à maturité pour ton objectif.",
        "Tu touches au but côté teinte.",
        "Ta peau affiche exactement la couleur visée."
    ]

    private static let deepState = [
        "Superbe hâle, profond et bien installé.",
        "Ta teinte est intense — objectif largement atteint.",
        "Beau bronzage abouti, riche et chaleureux.",
        "Ta peau affiche une couleur pleine et dorée.",
        "Hâle profond : tu es au sommet de ta teinte.",
        "Magnifique couleur, ta peau est joliment dorée.",
        "Teinte caramel bien marquée, mission accomplie.",
        "Bronzage à pleine maturité, vraiment réussi."
    ]

    // Observations secondaires
    private static let glowHigh = [
        "Et elle est lumineuse, pleine d'éclat.",
        "Avec un bel éclat en prime.",
        "Ta peau renvoie une jolie lumière.",
        "L'éclat est au rendez-vous."
    ]
    private static let glowLow = [
        "Elle paraît un peu terne, à raviver.",
        "L'éclat est en retrait aujourd'hui.",
        "Un peu de lumière en moins que d'habitude."
    ]
    private static let evenHigh = [
        "Le teint est remarquablement uniforme.",
        "La couleur est bien homogène.",
        "Un teint très régulier, c'est top."
    ]
    private static let evenLow = [
        "Le teint est un peu irrégulier par endroits.",
        "La couleur manque encore d'uniformité.",
        "Quelques zones inégales à lisser avec le temps."
    ]

    // Actions
    private static let burnActions = [
        "Mets ta peau à l'abri du soleil aujourd'hui et hydrate-la généreusement.",
        "Offre-lui une pause d'un jour ou deux, à l'ombre et au frais.",
        "Stoppe l'exposition, applique un soin apaisant et bois de l'eau.",
        "Couvre-toi et laisse-la récupérer avant la prochaine séance.",
        "Pas d'UV supplémentaires : place à l'hydratation et au repos.",
        "Protège-la avec un vêtement léger et attends qu'elle se calme."
    ]
    private static let irritationActions = [
        "Écourte ta prochaine exposition et pense à un SPF élevé.",
        "Lève le pied sur les UV et garde la peau bien hydratée.",
        "Une pause à l'ombre maintenant évitera le coup de soleil.",
        "Réduis un peu la dose et surveille comment elle évolue.",
        "Applique de la crème et privilégie les heures douces."
    ]
    private static let safeActions = [
        "Continue à petites doses, toujours avec ta protection.",
        "Garde ce rythme prudent, c'est exactement le bon esprit.",
        "Privilégie des expositions courtes et régulières.",
        "Reste sur des séances brèves, ta peau te remerciera.",
        "Avance tranquillement, le SPF reste ton meilleur allié."
    ]
    private static let maintainActions = [
        "Quelques expositions courtes suffiront à garder cette teinte.",
        "Un entretien léger et régulier maintiendra ta couleur.",
        "Pas besoin d'en faire plus : entretiens simplement.",
        "Espace les séances pour conserver ce résultat.",
        "Passe en mode entretien doux pour préserver ta couleur.",
        "Savoure : de courtes séances suffisent désormais."
    ]
    private static let glowActions = [
        "Vise des séances courtes pour entretenir un éclat naturel.",
        "Quelques minutes bien choisies suffisent pour ta bonne mine.",
        "Reste sur la finesse : peu d'UV, beaucoup d'éclat.",
        "Privilégie la régularité douce pour ce glow lumineux."
    ]
    private static let deepTanActions = [
        "Avance par paliers pour intensifier sans jamais brûler.",
        "Allonge progressivement, jamais d'un coup, vers ta teinte profonde.",
        "Augmente la dose petit à petit, avec un SPF adapté.",
        "Construis l'intensité dans la durée, séance après séance."
    ]
    private static let fairSkinReminder = [
        "Ta peau claire réclame un SPF généreux.",
        "Avec ton phototype clair, ne saute jamais la protection.",
        "Carnation claire oblige : garde la crème à portée de main.",
        "Sur peau claire, mieux vaut sous-doser les UV que l'inverse."
    ]
}

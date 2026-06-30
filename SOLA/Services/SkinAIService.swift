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
        String(localized: "Ta peau est nettement échauffée : signe qu'elle a eu sa dose d'UV pour aujourd'hui."),
        String(localized: "On voit des rougeurs marquées — ta peau te dit clairement stop."),
        String(localized: "Rougeur élevée détectée : ta peau est en train de réagir aux UV."),
        String(localized: "Ta peau montre des signes francs d'irritation après l'exposition."),
        String(localized: "Le rouge domine : ta peau a été poussée un peu trop loin."),
        String(localized: "Coup de chaud visible — la priorité passe à la récupération."),
        String(localized: "Les rougeurs sont nettes : ta peau a besoin de souffler."),
        String(localized: "Ta peau est échauffée et sensible aujourd'hui."),
        String(localized: "Rougeur importante : ce n'est vraiment pas le moment d'en rajouter."),
        String(localized: "Ta peau tire vers le rouge, elle a atteint sa limite du moment.")
    ]

    private static let irritationState = [
        String(localized: "Ta peau commence à rosir légèrement."),
        String(localized: "On perçoit un soupçon de rougeur sur ta peau."),
        String(localized: "Ta peau est un peu réactive aujourd'hui, sans excès."),
        String(localized: "Légère chaleur visible : ta peau a bien reçu les UV."),
        String(localized: "Un voile de rougeur apparaît, rien d'alarmant."),
        String(localized: "Ta peau pointe une petite réaction aux UV."),
        String(localized: "La teinte monte, avec un léger échauffement."),
        String(localized: "Ta peau rosit doucement — à garder à l'œil.")
    ]

    private static let freshState = [
        String(localized: "Ta peau est encore très claire, tout est à construire."),
        String(localized: "Point de départ tout en clarté : ton hâle ne fait que commencer."),
        String(localized: "Ta peau est nette et claire, prête pour un bronzage progressif."),
        String(localized: "Encore peu de hâle — c'est le tout début du parcours."),
        String(localized: "Ta carnation est claire et reposée."),
        String(localized: "Base claire : idéale pour bâtir un hâle en douceur."),
        String(localized: "Côté bronzage tu pars de zéro, et c'est parfait pour bien faire."),
        String(localized: "Teint clair et frais, sans signe de fatigue cutanée.")
    ]

    private static let buildingState = [
        String(localized: "Ton hâle s'installe joliment."),
        String(localized: "La teinte progresse dans la bonne direction."),
        String(localized: "Ton bronzage prend forme, étape par étape."),
        String(localized: "Belle progression : ta peau se dore peu à peu."),
        String(localized: "Le hâle monte régulièrement, sans à-coups."),
        String(localized: "Ta peau gagne en couleur tout en restant saine."),
        String(localized: "Tu es en bonne voie vers ta teinte cible."),
        String(localized: "La couleur s'approfondit doucement."),
        String(localized: "Ton bronzage avance à un bon rythme.")
    ]

    private static let onTargetState = [
        String(localized: "Tu y es presque : ta teinte approche ton objectif."),
        String(localized: "Ton hâle est pile dans la zone que tu vises."),
        String(localized: "Belle teinte, très proche de ta cible."),
        String(localized: "Ta couleur correspond à ce que tu recherches."),
        String(localized: "Objectif quasiment atteint, joli résultat."),
        String(localized: "Ton bronzage est à maturité pour ton objectif."),
        String(localized: "Tu touches au but côté teinte."),
        String(localized: "Ta peau affiche exactement la couleur visée.")
    ]

    private static let deepState = [
        String(localized: "Superbe hâle, profond et bien installé."),
        String(localized: "Ta teinte est intense — objectif largement atteint."),
        String(localized: "Beau bronzage abouti, riche et chaleureux."),
        String(localized: "Ta peau affiche une couleur pleine et dorée."),
        String(localized: "Hâle profond : tu es au sommet de ta teinte."),
        String(localized: "Magnifique couleur, ta peau est joliment dorée."),
        String(localized: "Teinte caramel bien marquée, mission accomplie."),
        String(localized: "Bronzage à pleine maturité, vraiment réussi.")
    ]

    // Observations secondaires
    private static let glowHigh = [
        String(localized: "Et elle est lumineuse, pleine d'éclat."),
        String(localized: "Avec un bel éclat en prime."),
        String(localized: "Ta peau renvoie une jolie lumière."),
        String(localized: "L'éclat est au rendez-vous.")
    ]
    private static let glowLow = [
        String(localized: "Elle paraît un peu terne, à raviver."),
        String(localized: "L'éclat est en retrait aujourd'hui."),
        String(localized: "Un peu de lumière en moins que d'habitude.")
    ]
    private static let evenHigh = [
        String(localized: "Le teint est remarquablement uniforme."),
        String(localized: "La couleur est bien homogène."),
        String(localized: "Un teint très régulier, c'est top.")
    ]
    private static let evenLow = [
        String(localized: "Le teint est un peu irrégulier par endroits."),
        String(localized: "La couleur manque encore d'uniformité."),
        String(localized: "Quelques zones inégales à lisser avec le temps.")
    ]

    // Actions
    private static let burnActions = [
        String(localized: "Mets ta peau à l'abri du soleil aujourd'hui et hydrate-la généreusement."),
        String(localized: "Offre-lui une pause d'un jour ou deux, à l'ombre et au frais."),
        String(localized: "Stoppe l'exposition, applique un soin apaisant et bois de l'eau."),
        String(localized: "Couvre-toi et laisse-la récupérer avant la prochaine séance."),
        String(localized: "Pas d'UV supplémentaires : place à l'hydratation et au repos."),
        String(localized: "Protège-la avec un vêtement léger et attends qu'elle se calme.")
    ]
    private static let irritationActions = [
        String(localized: "Écourte ta prochaine exposition et pense à un SPF élevé."),
        String(localized: "Lève le pied sur les UV et garde la peau bien hydratée."),
        String(localized: "Une pause à l'ombre maintenant évitera le coup de soleil."),
        String(localized: "Réduis un peu la dose et surveille comment elle évolue."),
        String(localized: "Applique de la crème et privilégie les heures douces.")
    ]
    private static let safeActions = [
        String(localized: "Continue à petites doses, toujours avec ta protection."),
        String(localized: "Garde ce rythme prudent, c'est exactement le bon esprit."),
        String(localized: "Privilégie des expositions courtes et régulières."),
        String(localized: "Reste sur des séances brèves, ta peau te remerciera."),
        String(localized: "Avance tranquillement, le SPF reste ton meilleur allié.")
    ]
    private static let maintainActions = [
        String(localized: "Quelques expositions courtes suffiront à garder cette teinte."),
        String(localized: "Un entretien léger et régulier maintiendra ta couleur."),
        String(localized: "Pas besoin d'en faire plus : entretiens simplement."),
        String(localized: "Espace les séances pour conserver ce résultat."),
        String(localized: "Passe en mode entretien doux pour préserver ta couleur."),
        String(localized: "Savoure : de courtes séances suffisent désormais.")
    ]
    private static let glowActions = [
        String(localized: "Vise des séances courtes pour entretenir un éclat naturel."),
        String(localized: "Quelques minutes bien choisies suffisent pour ta bonne mine."),
        String(localized: "Reste sur la finesse : peu d'UV, beaucoup d'éclat."),
        String(localized: "Privilégie la régularité douce pour ce glow lumineux.")
    ]
    private static let deepTanActions = [
        String(localized: "Avance par paliers pour intensifier sans jamais brûler."),
        String(localized: "Allonge progressivement, jamais d'un coup, vers ta teinte profonde."),
        String(localized: "Augmente la dose petit à petit, avec un SPF adapté."),
        String(localized: "Construis l'intensité dans la durée, séance après séance.")
    ]
    private static let fairSkinReminder = [
        String(localized: "Ta peau claire réclame un SPF généreux."),
        String(localized: "Avec ton phototype clair, ne saute jamais la protection."),
        String(localized: "Carnation claire oblige : garde la crème à portée de main."),
        String(localized: "Sur peau claire, mieux vaut sous-doser les UV que l'inverse.")
    ]
}

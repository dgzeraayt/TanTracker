import Foundation

// MARK: - B1 · Dose d'exposition cumulée
// Différenciateur clé : une météo affiche l'UV instantané ; SOLA additionne la
// DOSE reçue dans la journée et la rapporte au seuil sûr du phototype (MED).
//
// Principe (réutilise le calcul MED existant, `AppStore.safeMinutes(uv:)`) :
//  • Le « seuil sûr » du jour = minutes d'exposition avant rougeur à l'UV courant.
//  • Chaque minute passée au soleil consomme une fraction de ce seuil.
//  • Le SPF appliqué multiplie le temps disponible (protège), donc réduit la dose
//    consommée par minute.
//  • La dose est un pourcentage 0…100+ du plafond sûr ; ≥100 = seuil atteint.
//
// La dose se réinitialise chaque jour et est persistée localement.

struct ExposureDose {
    /// Fraction du seuil sûr consommée, 0…1+ (1 = plafond MED atteint).
    var fraction: Double
    /// Minutes équivalentes déjà « consommées » (pondérées SPF).
    var consumedMinutes: Double
    /// Minutes sûres totales disponibles aujourd'hui à l'UV courant.
    var safeMinutes: Double

    var percent: Int { Int((fraction * 100).rounded()) }
    var remainingMinutes: Int { max(0, Int((safeMinutes - consumedMinutes).rounded())) }

    enum Level { case safe, caution, high, reached }
    /// Paliers d'alerte : vert < 60 %, orange 60–80 %, rouge 80–100 %, plafond ≥ 100 %.
    var level: Level {
        switch fraction {
        case ..<0.60: return .safe
        case ..<0.80: return .caution
        case ..<1.0:  return .high
        default:      return .reached
        }
    }
}

enum ExposureCalculator {
    /// Facteur de protection effectif d'un SPF appliqué.
    /// On reste prudent : un SPF n'autorise pas un temps × indice complet
    /// (application imparfaite). On plafonne le bonus à ×4.
    static func protectionFactor(usedSPF: Bool, spf: Int) -> Double {
        guard usedSPF, spf > 1 else { return 1 }
        return min(4.0, sqrt(Double(spf)))
    }

    /// Dose consommée par une session : minutes / (seuil sûr × protection).
    /// `safeMinutesAtUV` = minutes sûres à l'UV de la session (MED existant).
    static func doseFraction(minutes: Int, safeMinutesAtUV: Int,
                             usedSPF: Bool, spf: Int) -> Double {
        guard safeMinutesAtUV > 0 else { return 0 }
        let protection = protectionFactor(usedSPF: usedSPF, spf: spf)
        let effectiveCeiling = Double(safeMinutesAtUV) * protection
        guard effectiveCeiling > 0 else { return 0 }
        return Double(minutes) / effectiveCeiling
    }
}

// MARK: - Intégration AppStore
extension AppStore {
    /// Dose cumulée du jour, calculée à partir des sessions d'aujourd'hui.
    /// Le seuil de référence est pris à l'UV fourni (ou de la session si connu).
    func todayDose(currentUV: Double) -> ExposureDose {
        let cal = Calendar.current
        let todaySessions = data.sessions.filter {
            $0.durationMinutes > 0 && cal.isDateInToday($0.date)
        }
        // Seuil sûr du jour à l'UV courant (réutilise le MED existant).
        let safeAtCurrent = Double(max(1, safeMinutes(uv: currentUV)))

        var consumed = 0.0
        for s in todaySessions {
            // Si la session connaît son UV, on l'utilise ; sinon l'UV courant.
            let uv = s.uvIndex > 0 ? s.uvIndex : currentUV
            let safeAtSession = max(1, safeMinutes(uv: uv))
            let frac = ExposureCalculator.doseFraction(
                minutes: s.durationMinutes,
                safeMinutesAtUV: safeAtSession,
                usedSPF: s.usedSPF,
                spf: profile.phototype.recommendedSPF)
            consumed += frac * safeAtCurrent  // exprimé en minutes-équivalent du jour
        }

        let fraction = safeAtCurrent > 0 ? consumed / safeAtCurrent : 0
        return ExposureDose(fraction: fraction,
                            consumedMinutes: consumed,
                            safeMinutes: safeAtCurrent)
    }
}

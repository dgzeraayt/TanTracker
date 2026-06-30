import SwiftUI

/// Transforme une chaîne **dynamique** (issue d'un modèle de données, ex. `step.cta`)
/// en `LocalizedStringKey` pour qu'elle soit traduite via le String Catalog.
/// Si la chaîne n'a pas d'entrée dans le catalogue, elle s'affiche telle quelle
/// (fallback = le français). Les littéraux, eux, restent passés directement.
func tr(_ string: String) -> LocalizedStringKey {
    LocalizedStringKey(stringLiteral: string)
}

/// Heure du jour (0–23) en libellé court localisé : fr « 14 h », en « 2 PM ».
func hourLabel(_ hour: Int) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? .now
    return date.formatted(.dateTime.hour())
}

/// Initiales des jours de la semaine, localisées et ordonnées **lundi en premier**.
/// Ex. fr : `["L","M","M","J","V","S","D"]`, en : `["M","T","W","T","F","S","S"]`.
var weekdayInitialsMondayFirst: [String] {
    var cal = Calendar.current
    cal.locale = Locale.autoupdatingCurrent
    let symbols = cal.veryShortWeekdaySymbols          // dimanche en premier
    return (0..<7).map { symbols[($0 + 1) % 7] }       // décalage → lundi en premier
}

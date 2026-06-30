import SwiftUI

/// Transforme une chaîne **dynamique** (issue d'un modèle de données, ex. `step.cta`)
/// en `LocalizedStringKey` pour qu'elle soit traduite via le String Catalog.
/// Si la chaîne n'a pas d'entrée dans le catalogue, elle s'affiche telle quelle
/// (fallback = le français). Les littéraux, eux, restent passés directement.
func tr(_ string: String) -> LocalizedStringKey {
    LocalizedStringKey(stringLiteral: string)
}

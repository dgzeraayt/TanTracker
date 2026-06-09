import Foundation

// Scoring inspiré du questionnaire Fitzpatrick (composante génétique).
// Chaque réponse a un poids ; le total mappe vers un phototype I–VI.
enum PhototypeScoring {

    // Les options sont présentées de la plus claire à la plus foncée.
    // eyeColor: 0 bleu clair … 3 marron foncé
    private static let eyePoints   = [0, 1, 2, 4]
    // hairColor: 0 blond/roux … 3 noir
    private static let hairPoints  = [0, 1, 3, 4]
    // skinTone: 0 très clair … 5 très foncé
    private static let skinPoints  = [0, 1, 3, 5, 6, 8]
    // sunReaction: 0 brûle toujours … 4 ne brûle jamais
    private static let reactPoints = [0, 2, 4, 6, 8]
    // freckles: 0 beaucoup … 3 aucune
    private static let freckPoints = [0, 1, 2, 3]

    static func compute(from p: UserProfile) -> Fitzpatrick {
        func at(_ arr: [Int], _ i: Int) -> Int { arr[min(max(0, i), arr.count - 1)] }
        let score = at(eyePoints, p.eyeColor)
                  + at(hairPoints, p.hairColor)
                  + at(skinPoints, p.skinTone)
                  + at(reactPoints, p.sunReaction)
                  + at(freckPoints, p.freckles)

        switch score {
        case ..<4:   return .I
        case 4..<8:  return .II
        case 8..<13: return .III
        case 13..<18: return .IV
        case 18..<24: return .V
        default:      return .VI
        }
    }
}

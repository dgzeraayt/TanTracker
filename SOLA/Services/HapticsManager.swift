import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Tap Feedback
    /// Léger (sélection, toggle)
    func tap() {
        selection.selectionChanged()
    }

    /// Moyen (bouton CTA, confirmation)
    func select() {
        impactMedium.impactOccurred()
    }

    /// Lourd (action majeure, succès)
    func success() {
        impactHeavy.impactOccurred()
        notification.notificationOccurred(.success)
    }

    /// Erreur
    func error() {
        notification.notificationOccurred(.error)
    }

    /// Warning
    func warning() {
        notification.notificationOccurred(.warning)
    }

    // MARK: - Patterns
    /// Double tap rapide (comme un like)
    func doubleTap() {
        impactLight.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactLight.impactOccurred()
        }
    }

    /// Pattern de célébration (3 taps progressifs)
    func celebration() {
        impactLight.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactMedium.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.impactHeavy.impactOccurred()
        }
    }
}

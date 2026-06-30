import SwiftUI

/// Bandeau de consentement analytics (opt-in RGPD). Non-dismissible : un choix est requis.
struct ConsentSheet: View {
    var onAccept: () -> Void
    var onRefuse: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Aide-nous à améliorer Goldn")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("On mesure l'usage de l'app de façon anonyme (via PostHog, hébergé en Europe) pour l'améliorer. Aucune donnée personnelle, pas de publicité. Tu peux refuser, l'app marche pareil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let url = URL(string: AnalyticsConfig.privacyPolicyURL) {
                Link("Politique de confidentialité", destination: url)
                    .font(.footnote)
            }
            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Accepter").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: onRefuse) {
                    Text("Refuser").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}

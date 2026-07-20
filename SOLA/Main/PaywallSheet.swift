import SwiftUI

// Paywall natif (design maîtrisé dans le code). Structure « hero » :
// photo pleine largeur fondue dans le fond, badge Premium, promesse, preuve
// sociale (note + communauté), deux offres côte à côte puis CTA. Contenu
// scrollable pour rester lisible sur petits écrans et gros Dynamic Type.
// Branché RevenueCat via PurchaseManager.
struct PaywallSheet: View {
    @EnvironmentObject var purchases: PurchaseManager
    /// Profil issu de l'onboarding + prévision du jour : servent à personnaliser
    /// les bénéfices avec les propres données de l'utilisateur.
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var forecastStore: ForecastStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Paywall bloquant (accès à l'app) : pas de bouton de fermeture.
    var mandatory: Bool = false
    /// Action « Passer » : si fournie, elle fait avancer dans l'app (présentation
    /// plein écran). Sinon, en sheet, le bouton ferme simplement le paywall.
    /// Appelée aussi après un achat/restauration réussi.
    var onSkip: (() -> Void)? = nil
    /// Action spécifique au bouton de fermeture (croix) — exit-intent. Si fournie,
    /// elle est appelée à la place de `onSkip` quand l'utilisateur ferme sans acheter
    /// (ex. lancer la roulette d'offre). Sans effet si le paywall est `mandatory`.
    var onClose: (() -> Void)? = nil

    @State private var selectedID = Self.initialPlanID
    @State private var showError = false

    /// Offre sélectionnée à l'ouverture. L'hebdo par défaut ; `SOLA_PAYWALL_PLAN`
    /// permet de forcer l'annuel en DEBUG pour produire les captures App Store
    /// sans dépendre d'un tap sur le simulateur.
    private static var initialPlanID: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SOLA_PAYWALL_PLAN"] == "annual" {
            return PurchaseManager.annualID
        }
        #endif
        return PurchaseManager.weeklyID
    }

    // Preuve sociale. Centralisée ici : ces deux chiffres sont des allégations
    // commerciales, ils doivent rester alignés sur la fiche App Store réelle.
    private static let ratingValue = "4,8/5"
    private static let audienceLabel = String(localized: "Plus de 10 000 utilisateurs")
    /// Visages de la banque d'images Goldn, en pastilles superposées.
    private static let communityFaces = [IMG.faceFreckles, IMG.faceSmile, IMG.facePortrait, IMG.faceMan]
    /// Part de la largeur occupée par la colonne photo du hero.
    private static let heroPhotoRatio: CGFloat = 0.52

    // Ce que l'abonnement débloque. Un bénéfice = une fonctionnalité qui existe
    // vraiment (UVService, ExposureTimer, NotificationManager, PhotoStore).
    /// `value` = la donnée personnelle, mise en avant ; `label` = ce qu'elle
    /// apporte. C'est le chiffre de l'utilisateur qui porte l'argument, pas
    /// une promesse générique.
    private struct Benefit { let img: String; let tint: Color; let value: String; let label: String }

    /// Bénéfices personnalisés avec ce que l'utilisateur a renseigné pendant
    /// l'onboarding (phototype, ville, objectif) et la prévision UV du jour.
    /// Tant qu'aucun fetch n'a abouti, `forecast` vaut `.sample` : on bascule
    /// alors sur des valeurs non chiffrées, plutôt que d'afficher des données de
    /// démo que l'utilisateur prendrait pour les siennes.
    private var benefits: [Benefit] {
        let p = store.profile
        let f = forecastStore.forecast
        let live = forecastStore.hasLoaded
        let city = p.city.split(separator: ",").first.map(String.init) ?? p.city
        let safeMin = store.safeMinutes(uv: f.maxToday)
        let type = p.phototype.roman
        return [
            Benefit(img: ClayIMG.sun, tint: Palette.amber,
                    value: live ? f.idealWindow : String(localized: "Chaque jour"),
                    label: live
                        ? String(localized: "Ton créneau d'aujourd'hui à \(city)")
                        : String(localized: "Ton créneau idéal, selon l'UV chez toi")),
            Benefit(img: ClayIMG.shield, tint: Palette.success,
                    value: live ? String(localized: "\(safeMin) min") : String(localized: "Peau type \(type)"),
                    label: live
                        ? String(localized: "Ta dose sûre du jour, peau type \(type)")
                        : String(localized: "Ta dose sûre est calculée pour elle")),
            Benefit(img: ClayIMG.bell, tint: Palette.terra,
                    value: live ? String(localized: "UV \(Int(f.maxToday.rounded())) aujourd'hui")
                                : String(localized: "Alerte auto"),
                    label: String(localized: "On te prévient avant que tu brûles")),
            Benefit(img: ClayIMG.personalization, tint: Palette.gold,
                    value: p.goal.title,
                    label: String(localized: "Ton plan et ta routine, jour après jour"))
        ]
    }

    private var selectedHasTrial: Bool { purchases.hasFreeTrial(for: selectedID) }
    private var ctaTitle: String {
        // Le montant nul est formaté dans la devise réelle du produit : « 0,00 € »
        // en France, « $0.00 » aux États-Unis. Coder « 0,00 € » en dur affichait
        // un symbole euro à des utilisateurs facturés en dollars.
        if selectedHasTrial {
            let zero = purchases.zeroPrice(for: selectedID, fallback: "0,00 €")
            return String(localized: "Commencer pour \(zero)")
        }
        return String(localized: "Continuer")
    }
    /// Essai de l'offre actuellement sélectionnée, s'il y en a un.
    private var selectedTrialLabel: String? { purchases.freeTrialLabel(for: selectedID) }
    /// Badge d'essai de l'annuel — `nil` dès que l'offre d'introduction est
    /// retirée d'App Store Connect, sans rien à changer ici.
    private var annualTrialBadge: String? {
        purchases.freeTrialLabel(for: PurchaseManager.annualID)
            .map { String(localized: "\($0) offerts") }
    }
    /// Volontairement sobre : la stratégie est de pousser l'hebdo, donc l'annuel
    /// ne porte aucun argument d'économie qui lui volerait la vedette.
    private var annualPerks: [String] {
        [purchases.annualPricePerMonth().map { String(localized: "Soit \($0)/mois") }].compactMap { $0 }
    }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = min(geo.size.width, Frame.maxContentWidth)
            ZStack(alignment: .top) {
                Palette.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    hero(safeTop: geo.safeAreaInsets.top, width: contentWidth)

                    benefitList
                        .padding(.horizontal, Frame.padH)
                        .padding(.top, 18)

                    // Respire avant les offres : le badge « essai gratuit » de la
                    // carte Hebdo déborde vers le haut, il lui faut de la place.
                    Spacer(minLength: 26)

                    VStack(spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            // L'hebdo est affiché au jour : le prix réellement
                            // facturé et sa période restent lisibles juste en
                            // dessous, la comparaison n'est pas masquée.
                            planCard(
                                id: PurchaseManager.weeklyID, title: String(localized: "Hebdomadaire"),
                                price: purchases.weeklyPricePerDay(fallback: "0,71 €"),
                                sub: String(localized: "par jour · facturé \(purchases.displayPrice(for: PurchaseManager.weeklyID, fallback: "4,99 €"))/sem"),
                                badge: purchases.freeTrialLabel(for: PurchaseManager.weeklyID)
                                    .map { String(localized: "\($0) offerts") },
                                perks: [String(localized: "Sans engagement")])
                            planCard(
                                id: PurchaseManager.annualID, title: String(localized: "Annuel"),
                                price: purchases.displayPrice(for: PurchaseManager.annualID, fallback: "24,99 €"),
                                sub: String(localized: "par an"),
                                badge: annualTrialBadge,
                                perks: annualPerks)
                        }
                        ctaButton
                        Text(footnote)
                            .font(SolaFont.caption).foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity, alignment: .center)
                        footerLinks.padding(.top, 2)
                    }
                    // Le hero saigne bord à bord : la gouttière est appliquée
                    // au bloc offres seulement, pas au VStack entier.
                    .padding(.horizontal, Frame.padH)
                }
                .padding(.bottom, geo.safeAreaInsets.bottom + 14)
                .frame(width: contentWidth, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                // Écran fixe quand tout tient ; devient défilable seulement si le
                // contenu déborde (petits écrans / gros Dynamic Type) pour ne rien rogner.
                .solaScrollableIfNeeded()

                topBar
                    .padding(.horizontal, Frame.padH)
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.top, geo.safeAreaInsets.top + 6)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .alert("Achat indisponible", isPresented: $showError) {
            Button("Réessayer") { Task { await purchases.loadOfferings() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.lastError ?? String(localized: "Impossible de contacter la boutique. Vérifie ta connexion puis réessaie."))
        }
        .task {
            if purchases.offering == nil { await purchases.loadOfferings() }
        }
        .task {
            // Prévision du jour pour personnaliser les bénéfices. `loadIfNeeded`
            // déduplique : si un autre écran l'a déjà chargée, aucun appel réseau.
            let p = store.profile
            await forecastStore.loadIfNeeded(lat: p.latitude, lon: p.longitude, city: p.city)
        }
        .onAppear {
            Analytics.capture(.paywallViewed(source: "main", variant: Experiments.variant(.paywallLayout)))
        }
    }

    private var footnote: String {
        if let t = selectedTrialLabel, selectedHasTrial {
            return String(localized: "\(t) offerts · Annulable à tout moment")
        }
        return String(localized: "Sans engagement · Annulable à tout moment")
    }

    // MARK: - Barre supérieure (Restaurer / fermer)
    private var topBar: some View {
        HStack {
            Button {
                Task {
                    let restored = await purchases.restorePurchases()
                    if restored {
                        if let onSkip { onSkip() } else if !mandatory { dismiss() }
                    } else { showError = true }
                }
            } label: {
                Text("Restaurer")
                    .font(SolaFont.body(15, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .buttonStyle(.plain)

            Spacer()

            if !mandatory {
                Button {
                    if let onClose { onClose() }
                    else if let onSkip { onSkip() }
                    else { dismiss() }
                } label: {
                    Icon(name: "x", size: 16, stroke: 2.5)
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 34, height: 34)
                        .background(GlassCircle(tint: Palette.surface, tintOpacity: 0.36))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero (texte à gauche, photo en colonne à droite)
    // La photo occupe la moitié droite, saigne en haut et à droite, et son bord
    // gauche est fondu par un masque dégradé pour se raccorder au fond. C'est le
    // texte qui dicte la hauteur : le hero grandit seul en gros Dynamic Type.
    private func hero(safeTop: CGFloat, width: CGFloat) -> some View {
        heroText
            .padding(.leading, Frame.padH)
            // Le texte déborde volontairement sous le bord fondu de la photo :
            // la marge est plus courte que la colonne image, sinon les lignes
            // se retrouvent à l'étroit et cassent en 3.
            .padding(.trailing, width * 0.30)
            .padding(.top, safeTop + 44)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) { heroPhoto(width: width) }
    }

    private func heroPhoto(width: CGFloat) -> some View {
        Color.clear
            .overlay {
                Image(IMG.faceSoft)
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: width * Self.heroPhotoRatio)
            .clipped()
            // Fondu long sur le bord gauche : la photo se dissout dans le fond
            // pour que le texte qui passe dessous reste lisible.
            .mask(
                LinearGradient(stops: [
                    .init(color: .black.opacity(0), location: 0.00),
                    .init(color: .black.opacity(0.55), location: 0.30),
                    .init(color: .black, location: 0.58)
                ], startPoint: .leading, endPoint: .trailing)
            )
            // Second masque, vertical : évite la coupe nette au raccord avec la
            // carte des bénéfices. Les deux masques se multiplient.
            .mask(
                LinearGradient(stops: [
                    .init(color: .black, location: 0.00),
                    .init(color: .black, location: 0.58),
                    .init(color: .black.opacity(0.45), location: 0.82),
                    .init(color: .black.opacity(0), location: 1.00)
                ], startPoint: .top, endPoint: .bottom)
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .allowsHitTesting(false)
    }

    // Le sous-titre du mockup a sauté : il répétait ce que la liste de bénéfices
    // dit mieux, et c'est lui qui faisait déborder l'écran.
    private var heroText: some View {
        VStack(alignment: .leading, spacing: 0) {
            premiumBadge
            Text("Bronze plus vite,\nsans te brûler")
                .font(SolaFont.display(28, weight: .heavy)).tracking(-0.7)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 11)
            socialProof.padding(.top, 14)
        }
    }

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11)).foregroundStyle(Palette.bronze)
            Text("PREMIUM")
                .font(SolaFont.sectionLabel).tracking(1.4)
                .foregroundStyle(Palette.bronze)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Palette.tintGold))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1))
    }

    // Avatars + note sur une seule rangée : les deux preuves sociales du mockup,
    // sans les trois lignes de texte qui cassaient la colonne.
    private var socialProof: some View {
        HStack(spacing: 10) {
            HStack(spacing: -9) {
                ForEach(Self.communityFaces, id: \.self) { face in
                    Image(face)
                        .resizable().scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Palette.bg, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                ratingRow
                Text(Self.audienceLabel)
                    .font(SolaFont.body(11.5)).foregroundStyle(Palette.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Preuve sociale (note App Store)
    private var ratingRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 1.5) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11)).foregroundStyle(Palette.gold)
                }
            }
            Text(Self.ratingValue)
                .font(SolaFont.body(13, weight: .heavy)).foregroundStyle(Palette.ink)
        }
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    // MARK: - Bénéfices
    // Le cœur du paywall : ce que l'abonnement débloque, lisible en un coup d'œil.
    // Une ligne par bénéfice, dans une carte : ça structure le milieu de l'écran
    // et ça tient sans scroll. Les libellés sont bornés à une ligne.
    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { _, b in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(b.tint.opacity(0.16)).frame(width: 38, height: 38)
                        ClayAssetImage(name: b.img, size: 22, shadow: false)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(b.value)
                            .font(SolaFont.body(16.5, weight: .heavy)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(b.label)
                            .font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassPanel(radius: Radius.lg, tint: Palette.surface, tintOpacity: 0.42))
    }

    // MARK: - Carte d'offre (sélectionnable, format vertical côte à côte)
    // `badge` = l'argument d'accroche qui déborde en haut (essai / économie),
    // `perks` = ce qui distingue cette offre de l'autre. Les fonctionnalités,
    // elles, sont identiques sur les deux offres : elles restent dans la liste
    // de bénéfices au-dessus, pas dupliquées ici.
    private func planCard(id: String, title: String, price: String, sub: String,
                          badge: String?, perks: [String]) -> some View {
        let selected = selectedID == id
        return Button {
            HapticsManager.shared.select()
            selectedID = id
            Analytics.capture(.paywallPlanSelected(plan: id))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if selected {
                            Circle().fill(Palette.amberDeep).frame(width: 22, height: 22)
                            Icon(name: "check", size: 11, stroke: 3).foregroundStyle(.white)
                        }
                    }
                }
                Text(price).font(SolaFont.display(24, weight: .heavy)).tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // Deux lignes réservées même quand le texte n'en occupe qu'une :
                // c'est ce qui garde les deux cartes exactement à la même hauteur.
                Text(sub).font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(perks, id: \.self) { perk in
                    HStack(spacing: 5) {
                        Icon(name: "check", size: 10, stroke: 3.5)
                            .foregroundStyle(Palette.success)
                        Text(perk)
                            .font(SolaFont.body(12, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassPanel(radius: Radius.lg,
                                   tint: selected ? Palette.accentSoft : Palette.surface,
                                   tintOpacity: selected ? 0.5 : 0.30))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Palette.amberDeep : Palette.line, lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge.uppercased())
                        .font(SolaFont.dataSmall).tracking(0.3)
                        .foregroundStyle(Palette.onAmber)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Palette.gold))
                        .shadowSoft()
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .pressAnimation()
        // Marge constante : la place du badge est réservée sur les deux cartes,
        // sinon celle qui n'en a pas remonterait de 8 pt.
        .padding(.top, 8)
    }

    // MARK: - CTA
    private var ctaButton: some View {
        Button {
            Task {
                if purchases.offering == nil {
                    await purchases.loadOfferings()
                    if purchases.offering == nil { showError = true; return }
                }
                let ok = await purchases.purchase(selectedID)
                if ok {
                    if let onSkip { onSkip() }
                    else if !mandatory { dismiss() }
                } else if purchases.lastError != nil {
                    showError = true
                }
            }
        } label: {
            ZStack {
                if purchases.purchasing {
                    ProgressView().tint(Palette.onAmber)
                } else {
                    Text(ctaTitle).font(SolaFont.body(17, weight: .bold)).foregroundStyle(Palette.onAmber)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(Capsule().fill(Palette.amber))
            .shadowSoft()
        }
        .buttonStyle(.plain)
        .pressAnimation()
        .disabled(purchases.purchasing)
    }

    // MARK: - Liens légaux
    private var footerLinks: some View {
        HStack(spacing: 22) {
            Button("Confidentialité") { openURL(URL(string: "https://goldnapp.com/privacy")!) }
            Text("·").foregroundStyle(Palette.ink3)
            Button("EULA") { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
        }
        .font(SolaFont.body(11.5))
        .foregroundStyle(Palette.ink3)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(1).minimumScaleFactor(0.85)
    }
}

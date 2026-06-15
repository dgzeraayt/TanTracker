import SwiftUI

// MARK: - A2 · Analyse IA de ta teinte
struct AppAnalysis: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var purchases: PurchaseManager
    @State private var picked: UIImage?
    @State private var transientPhoto: UIImage?
    @State private var transientMetrics: SkinMetrics?
    @State private var showPicker = false
    @State private var showLibrary = false
    @State private var showPaywall = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    /// Scan toujours autorisé : pas de quota. L'accès est géré en amont par le
    /// paywall obligatoire (essai gratuit annuel), pas par un compteur d'analyses.
    private var canScan: Bool { true }
    private func requestScan() {
        if canScan { showPicker = true } else { showPaywall = true }
    }

    private var latestPhotoSession: TanSession? { store.lastPhotoSessions.last }
    private var photo: UIImage? {
        if let img = transientPhoto { return img }
        if let name = latestPhotoSession?.photoFilename { return PhotoStore.load(name) }
        return nil
    }
    private var metrics: SkinMetrics? {
        transientMetrics ?? latestPhotoSession?.metrics
    }

    private func cards(_ m: SkinMetrics) -> [(String, String, String, Color)] {
        [
            ("drop", "Niv. \(m.tanLevel)", "Teinte", Palette.terra),
            ("sparkle", "\(m.glow)%", "Éclat", Palette.amberDeep),
            ("wave", "\(m.evenness)%", "Unif.", Palette.bronze)
        ]
    }

    private func analysisPhotoLayer(size: CGSize) -> some View {
        Group {
            if let img = photo {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                RemoteImage(url: IMG.facePortrait, tone: .deep)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(Color.black.opacity(0.10))
    }

    var body: some View {
        ScreenScaffold(background: Color.black, lightStatusBar: true) {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    analysisPhotoLayer(size: geo.size)
                        .ignoresSafeArea()

                    if let img = photo, (isAnalyzing || metrics != nil) {
                        FaceScanMesh(image: img, containerSize: geo.size, sweeping: isAnalyzing)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    } else if metrics == nil {
                        let side = min(geo.size.width * 0.56, 216)
                        ScanReticle(scanning: isAnalyzing)
                            .frame(width: side, height: side * 1.18)
                            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.30)
                            .allowsHitTesting(false)
                    }

                    VStack(spacing: 0) {
                        // Zone photo : la photo est dessinée une seule fois en fond plein écran.
                        ZStack {
                            Color.clear

                            // Dégradé de lisibilité sous le header
                            VStack {
                                LinearGradient(colors: [.black.opacity(0.5), .clear],
                                               startPoint: .top, endPoint: .bottom)
                                    .frame(height: 150)
                                Spacer()
                            }
                            .allowsHitTesting(false)

                            // Indication de cadrage par-dessus la photo
                            if let err = analysisError, !isAnalyzing, photo != nil {
                                framingHint(err)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea(edges: .top)

                        // Panneau résultats (bas), légèrement posé sur la photo pour éviter une bande sombre.
                        analysisPanel
                            .padding(.horizontal, Frame.padH)
                            .padding(.top, -18)
                            .zIndex(1)
                    }
                    // Dégage la tab bar flottante (~68 + marge) pour ne pas la chevaucher.
                    .padding(.bottom, geo.safeAreaInsets.bottom + 84)

                    // Header par-dessus la photo (onglet racine : pas de flèche retour).
                    HStack {
                        Color.clear.frame(width: 46, height: 46)
                        Spacer()
                        Text("Analyse de peau")
                            .font(SolaFont.display(20, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Button { requestScan() } label: {
                            Icon(name: "refresh", size: 20, stroke: 2.2).foregroundStyle(.white)
                                .frame(width: 46, height: 46).background(GlassCircle())
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, Frame.padH)
                    .padding(.top, 4)
                }
            }
        }
        .fullScreenCover(isPresented: $showPicker) {
            FaceScanScreen(
                onCaptured: { img in showPicker = false; picked = img },
                onCancel: { showPicker = false },
                onPickLibrary: { showPicker = false; showLibrary = true }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) { CameraPhotoPicker(image: $picked, preferCamera: false) }
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
        .onChange(of: picked) { _, img in
            if let img {
                saveAndAnalyze(img)
            }
        }
        .onAppear(perform: analyzeStoredPhotoIfNeeded)
    }

    @ViewBuilder
    private var analysisPanel: some View {
        if let m = metrics {
            CardBox(padding: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("État de ta peau")
                            .font(SolaFont.display(22, weight: .bold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Badge(text: "On-device", icon: "sparkle", style: .normal)
                    }
                    .padding(.bottom, 14)
                    // Grille 2×2 des mesures (icône ronde colorée + libellé + valeur)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            conditionCard("drop", Palette.terra, "Teinte", "\(m.tan)%")
                            conditionCard("sparkle", Palette.amberDeep, "Éclat", "\(m.glow)%")
                        }
                        HStack(spacing: 10) {
                            conditionCard("flame", Palette.alert, "Rougeur", "\(m.redness)%")
                            conditionCard("wave", Palette.bronze, "Uniformité", "\(m.evenness)%")
                        }
                    }
                    if let advice = m.advice, !advice.isEmpty {
                        HStack(alignment: .top, spacing: 9) {
                            Icon(name: "sparkle", size: 16).foregroundStyle(Palette.amberDeep)
                                .padding(.top, 1)
                            Text(advice)
                                .font(SolaFont.body(13))
                                .foregroundStyle(Palette.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GlassPanel(radius: 16, tint: Palette.tintAmber, tintOpacity: 0.42))
                        .padding(.top, 12)
                    }
                    SolaButton(title: "Nouvelle photo",
                               kind: .amber, icon: "camera") { requestScan() }
                        .padding(.top, 16)
                }
            }
        } else if isAnalyzing {
            CardBox(padding: 22) {
                VStack(spacing: 12) {
                    Eyebrow(text: "Analyse IA").frame(maxWidth: .infinity)
                    Text("L'IA étudie ta peau…")
                        .font(SolaFont.display(23, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("On mesure ta teinte, ton éclat, l'uniformité et la rougeur.")
                        .font(SolaFont.body(13.5)).foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView().tint(Palette.amberDeep).padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            CardBox(padding: 22) {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Eyebrow(text: analysisError == nil ? "Analyse IA" : "Réessaie")
                            .frame(maxWidth: .infinity)
                        Text(analysisError == nil ? "Scanne ta peau" : "Recadre ton selfie")
                            .font(SolaFont.display(25, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(analysisError ?? "Un selfie en lumière naturelle. L'IA évalue ta teinte, ton éclat, l'uniformité et la rougeur.")
                            .font(SolaFont.body(13.5)).foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Aperçu de ce que tu obtiendras
                    HStack(spacing: 7) {
                        metricChip("drop", "Teinte")
                        metricChip("sparkle", "Éclat")
                        metricChip("wave", "Unif.")
                        metricChip("flame", "Rougeur")
                    }
                    SolaButton(title: photo == nil ? "Prendre une photo" : "Réessayer",
                               kind: .amber, icon: "camera") { requestScan() }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func metricChip(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Icon(name: icon, size: 16).foregroundStyle(Palette.bronze)
            Text(label).font(SolaFont.body(11, weight: .semibold)).foregroundStyle(Palette.ink3)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(GlassPanel(radius: 14, tint: Palette.bgWarm, tintOpacity: 0.30))
    }

    /// Consigne de cadrage d'après la boîte du visage (coords normalisées Vision).
    /// nil = cadrage correct. Évalué après la prise (caméra système non pilotable).
    private func framingGuidance(_ box: SkinFaceBox?) -> String? {
        guard let box else {
            return "Aucun visage détecté. Place ton visage dans le cadre, en pleine lumière."
        }
        if box.height > 0.92 || box.width > 0.92 {
            return "Recule un peu : ton visage est trop près de l'objectif."
        }
        if box.height < 0.30 {
            return "Rapproche-toi : ton visage est trop loin pour une analyse fiable."
        }
        let centerX = box.x + box.width / 2
        if centerX < 0.24 || centerX > 0.76 {
            return "Centre ton visage dans le cadre."
        }
        return nil
    }

    // Bulle d'indication de cadrage, centrée sur la photo.
    private func framingHint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Icon(name: "camera", size: 17).foregroundStyle(Palette.gold)
            Text(text)
                .font(SolaFont.body(14.5, weight: .semibold)).foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(maxWidth: 290)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .padding(.horizontal, 28)
    }

    // Carte de mesure façon « Skin Condition » : pastille ronde colorée à gauche,
    // libellé au-dessus de la valeur.
    private func conditionCard(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 11) {
            Icon(name: icon, size: 18, stroke: 2.2).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1))
                .shadow(color: tint.opacity(0.24), radius: 7, y: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(value).font(SolaFont.display(19, weight: .heavy)).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11).padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1))
        )
    }

    private func metricTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Icon(name: icon, size: 22).foregroundStyle(color)
            Text(value)
                .font(SolaFont.display(22, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(SolaFont.body(12.5)).foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }

    private func annotation(_ a: AnalysisAnnotation) -> some View {
        let trailing = a.side == .right
        return HStack(spacing: 8) {
            if trailing {
                VStack(alignment: .trailing, spacing: 0) { annoText(a.label, a.value) }
                dot
            } else {
                dot
                VStack(alignment: .leading, spacing: 0) { annoText(a.label, a.value) }
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
    }

    private var dot: some View {
        Circle().fill(.white.opacity(0.9)).frame(width: 13, height: 13)
            .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 4))
    }

    @ViewBuilder
    private func annoText(_ k: String, _ v: String) -> some View {
        Text(k.uppercased()).font(SolaFont.mono(10)).tracking(0.8).foregroundStyle(.white.opacity(0.78))
        Text(v)
            .font(SolaFont.body(16, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }

    private func saveAndAnalyze(_ image: UIImage) {
        transientMetrics = nil
        analysisError = nil
        isAnalyzing = true

        guard let filename = PhotoStore.save(image),
              let saved = PhotoStore.load(filename) else {
            isAnalyzing = false
            analysisError = "La photo n'a pas pu être enregistrée."
            return
        }

        transientPhoto = saved
        analyze(saved, filename: filename, createsSession: true)
    }

    private func analyzeStoredPhotoIfNeeded() {
        guard metrics == nil,
              !isAnalyzing,
              let filename = latestPhotoSession?.photoFilename,
              let img = PhotoStore.load(filename) else { return }
        analysisError = nil
        isAnalyzing = true
        analyze(img, filename: filename, createsSession: false)
    }

    private func analyze(_ image: UIImage, filename: String, createsSession: Bool) {
        // Capture le profil (valeur) avant de quitter le contexte principal.
        let profile = store.profile
        let scanStart = Date()
        Task {
            // Mesure + boîte du visage (hors main thread : traitement pixel + Vision).
            let outcome: (metrics: SkinMetrics?, faceBox: SkinFaceBox?) =
                await Task.detached(priority: .userInitiated) {
                    let m = SkinAnalysis.analyze(image)
                    return (m, m?.faceBox ?? SkinAnalysis.faceBox(in: image))
                }.value
            let measured = outcome.metrics

            // Conseil généré on-device à partir des mesures : instantané, hors-ligne.
            var result = measured
            if let measured { result?.advice = SkinAdvice.make(for: measured, profile: profile) }

            // Contrôle de cadrage : guide l'utilisateur si le visage est trop près /
            // loin / hors champ (impossible en direct avec la caméra système).
            let guidance = framingGuidance(outcome.faceBox)

            // Laisse l'animation de scan se dérouler (l'analyse est quasi instantanée).
            let minScan = 2.4
            let elapsed = Date().timeIntervalSince(scanStart)
            if elapsed < minScan {
                try? await Task.sleep(nanoseconds: UInt64((minScan - elapsed) * 1_000_000_000))
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) { isAnalyzing = false }
                // Cadrage à corriger : on guide plutôt que d'afficher une mesure douteuse.
                if let guidance {
                    analysisError = guidance
                    if createsSession {
                        store.addSession(TanSession(durationMinutes: 0, usedSPF: false, uvIndex: 0,
                                                    note: "Cadrage à revoir", photoFilename: filename, metrics: nil))
                    }
                    return
                }
                guard let result else {
                    analysisError = "Prends une photo plus nette, avec le visage en lumière naturelle."
                    if createsSession {
                        store.addSession(TanSession(durationMinutes: 0, usedSPF: false, uvIndex: 0,
                                                    note: "Analyse incomplète", photoFilename: filename, metrics: nil))
                    }
                    return
                }

                transientMetrics = result
                if createsSession {
                    store.addSession(TanSession(durationMinutes: 0, usedSPF: false, uvIndex: 0,
                                                note: "Analyse", photoFilename: filename, metrics: result))
                } else {
                    store.updateMetrics(result, forPhoto: filename)
                }
            }
        }
    }

    private enum AnnotationSide { case left, right }
    private struct AnalysisAnnotation: Identifiable {
        let id: String
        let label: String
        let value: String
        let point: CGPoint
        let side: AnnotationSide
    }

    private func annotations(_ m: SkinMetrics, photo: UIImage, in size: CGSize) -> [AnalysisAnnotation] {
        guard let box = m.faceBox?.cgRect, photo.size.width > 0, photo.size.height > 0 else {
            return fallbackAnnotations(m, in: size)
        }

        let imageRect = displayedImageRect(for: photo.size, in: size)
        func screenPoint(_ relX: CGFloat, _ relY: CGFloat, side: AnnotationSide) -> CGPoint {
            let nx = box.minX + box.width * relX
            let ny = box.minY + box.height * relY
            let raw = CGPoint(x: imageRect.minX + nx * imageRect.width,
                              y: imageRect.minY + (1 - ny) * imageRect.height)
            return clamp(raw, side: side, in: size)
        }

        return [
            AnalysisAnnotation(id: "tone", label: "Teinte", value: m.hueLabel,
                               point: screenPoint(0.86, 0.74, side: .right), side: .right),
            AnalysisAnnotation(id: "glow", label: "Éclat", value: "\(m.glow)%",
                               point: screenPoint(0.08, 0.54, side: .left), side: .left),
            AnalysisAnnotation(id: "redness", label: "Rougeur", value: "\(m.redness)%",
                               point: screenPoint(0.88, 0.38, side: .right), side: .right),
            AnalysisAnnotation(id: "evenness", label: "Uniformité", value: "\(m.evenness)%",
                               point: screenPoint(0.12, 0.22, side: .left), side: .left)
        ]
    }

    private func fallbackAnnotations(_ m: SkinMetrics, in size: CGSize) -> [AnalysisAnnotation] {
        [
            AnalysisAnnotation(id: "tone", label: "Teinte", value: m.hueLabel,
                               point: CGPoint(x: size.width - 108, y: size.height * 0.30), side: .right),
            AnalysisAnnotation(id: "glow", label: "Éclat", value: "\(m.glow)%",
                               point: CGPoint(x: 112, y: size.height * 0.42), side: .left),
            AnalysisAnnotation(id: "redness", label: "Rougeur", value: "\(m.redness)%",
                               point: CGPoint(x: size.width - 106, y: size.height * 0.54), side: .right),
            AnalysisAnnotation(id: "evenness", label: "Uniformité", value: "\(m.evenness)%",
                               point: CGPoint(x: 118, y: size.height * 0.66), side: .left)
        ]
    }

    private func displayedImageRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
        let scale = max(container.width / imageSize.width, container.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - fitted.width) / 2,
                      y: (container.height - fitted.height) / 2,
                      width: fitted.width,
                      height: fitted.height)
    }

    private func clamp(_ point: CGPoint, side: AnnotationSide, in size: CGSize) -> CGPoint {
        let minX: CGFloat = side == .left ? 92 : 116
        let maxX: CGFloat = side == .left ? size.width - 116 : size.width - 92
        let minY: CGFloat = 172
        let maxY = max(minY, size.height - 282)
        return CGPoint(x: min(max(point.x, minX), maxX),
                       y: min(max(point.y, minY), maxY))
    }
}

// MARK: - Viseur d'analyse (cadre à coins + ligne de scan)
private struct ScanReticle: View {
    var scanning: Bool
    @State private var animate = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                ReticleCorners(cornerLength: 30, radius: 22)
                    .stroke(Color.white.opacity(0.92),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                if scanning {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(LinearGradient(colors: [.clear, Palette.gold.opacity(0.95), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                        .shadow(color: Palette.gold.opacity(0.6), radius: 8)
                        .offset(y: animate ? g.size.height / 2 - 20 : -g.size.height / 2 + 20)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)
                }
            }
            .onAppear { animate = true }
        }
    }
}

// Dessine uniquement les 4 équerres d'angle d'un rectangle arrondi.
struct ReticleCorners: Shape {
    var cornerLength: CGFloat
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = radius, L = cornerLength
        // haut-gauche
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r + L))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r + L, y: rect.minY))
        // haut-droit
        p.move(to: CGPoint(x: rect.maxX - r - L, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r + L))
        // bas-droit
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - L))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - r - L, y: rect.maxY))
        // bas-gauche
        p.move(to: CGPoint(x: rect.minX + r + L, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r - L))
        return p
    }
}

// Rectangle d'affichage d'une image en mode .scaledToFill dans un conteneur.
private func scanDisplayedImageRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
    let scale = max(container.width / imageSize.width, container.height / imageSize.height)
    let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(x: (container.width - fitted.width) / 2,
                  y: (container.height - fitted.height) / 2,
                  width: fitted.width, height: fitted.height)
}

private func scanFaceRect(_ box: SkinFaceBox, in imageRect: CGRect) -> CGRect {
    CGRect(x: imageRect.minX + CGFloat(box.x) * imageRect.width,
           y: imageRect.minY + CGFloat(1 - box.y - box.height) * imageRect.height,
           width: CGFloat(box.width) * imageRect.width,
           height: CGFloat(box.height) * imageRect.height)
}

// MARK: - Scan futuriste : maillage de repères + équerres + ligne de balayage
private struct FaceScanMesh: View {
    let image: UIImage
    let containerSize: CGSize
    var sweeping: Bool = true          // true : balayage animé ; false : maillage figé
    @State private var meshN: SkinFaceMeshData?
    @State private var start = Date()

    var body: some View {
        let rect = scanDisplayedImageRect(for: image.size, in: containerSize)
        let pointsN = meshN?.points ?? []
        let pts = pointsN.map { CGPoint(x: rect.minX + $0.x * rect.width,
                                        y: rect.minY + $0.y * rect.height) }
        let face = meshN.map { scanFaceRect($0.faceBox, in: rect) } ?? Self.bounds(of: pts)
        let maxLinkDistance = max(34, min(face?.width ?? 0, face?.height ?? 0) * 0.24)
        let edges = Self.edges(for: pts, maxDistance: maxLinkDistance)

        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, _ in
                guard let face, !pts.isEmpty else { return }
                let reveal = sweeping ? min(1, t / 1.2) : 1
                let sweepY: CGFloat? = sweeping
                    ? face.minY + face.height * CGFloat((t.truncatingRemainder(dividingBy: 2.0)) / 2.0)
                    : nil
                func near(_ y: CGFloat) -> Double {
                    guard let s = sweepY else { return 0 }
                    return max(0, 1 - Double(abs(y - s)) / 55)
                }

                // Équerres autour du visage détecté
                let bracket = face.insetBy(dx: -16, dy: -22)
                ctx.stroke(ReticleCorners(cornerLength: 26, radius: 18).path(in: bracket),
                           with: .color(.white.opacity(0.92 * reveal)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Lignes du maillage (plus lumineuses près de la ligne de scan)
                for e in edges {
                    let a = pts[e.0], b = pts[e.1]
                    let n = near((a.y + b.y) / 2)
                    var path = Path(); path.move(to: a); path.addLine(to: b)
                    ctx.stroke(path, with: .color(.white.opacity((0.22 + 0.5 * n) * reveal)), lineWidth: 0.8)
                }

                // Nœuds, révélés progressivement et illuminés au passage du scan
                for (i, p) in pts.enumerated() where Double(i) / Double(pts.count) <= reveal {
                    let n = near(p.y)
                    let r = 1.6 + 1.8 * n
                    let dot = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    let color: Color = n > 0.55 ? Palette.gold : .white
                    ctx.fill(Path(ellipseIn: dot), with: .color(color.opacity(0.6 + 0.4 * n)))
                }

                // Ligne de balayage horizontale (uniquement pendant le scan)
                if let s = sweepY {
                    var line = Path()
                    line.move(to: CGPoint(x: face.minX - 12, y: s))
                    line.addLine(to: CGPoint(x: face.maxX + 12, y: s))
                    ctx.stroke(line,
                               with: .linearGradient(Gradient(colors: [.clear, Palette.gold.opacity(0.9), .clear]),
                                                     startPoint: CGPoint(x: face.minX, y: s),
                                                     endPoint: CGPoint(x: face.maxX, y: s)),
                               lineWidth: 2)
                }
            }
        }
        .task(id: ObjectIdentifier(image)) {
            start = Date()
            meshN = nil
            let img = image
            let mesh = await Task.detached(priority: .userInitiated) {
                let mesh = SkinAnalysis.faceMesh(in: img)
                return mesh
            }.value
            meshN = mesh
        }
    }

    private static func bounds(of pts: [CGPoint]) -> CGRect? {
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Relie chaque point à ses 3 plus proches voisins → réseau type constellation.
    private static func edges(for pts: [CGPoint], maxDistance: CGFloat) -> [(Int, Int)] {
        guard pts.count > 2 else { return [] }
        let maxSquared = maxDistance * maxDistance
        var seen = Set<Int>(); var out: [(Int, Int)] = []
        for i in pts.indices {
            let neighbours = pts.indices.filter { $0 != i }
                .sorted { sqDist(pts[i], pts[$0]) < sqDist(pts[i], pts[$1]) }
                .prefix(3)
            for j in neighbours {
                guard sqDist(pts[i], pts[j]) <= maxSquared else { continue }
                let key = i < j ? i * 100_000 + j : j * 100_000 + i
                if seen.insert(key).inserted { out.append((i, j)) }
            }
        }
        return out
    }
    private static func sqDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y; return dx * dx + dy * dy
    }
}

// MARK: - A5 · Recommandations + minuteur fonctionnel
struct AppReco: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @EnvironmentObject var forecastStore: ForecastStore
    @Environment(\.dismiss) private var dismiss
    @State private var showTimer = false
    private var forecast: UVForecast { forecastStore.forecast }

    private var safeMin: Int { store.safeMinutes(uv: forecast.current) }
    private var perFace: Int { max(1, safeMin / 2) }
    private var limitTime: String {
        let end = Date().addingTimeInterval(TimeInterval(safeMin * 60))
        let f = DateFormatter(); f.dateFormat = "HH'h'mm"; return f.string(from: end)
    }
    private var params: [(String, String, String, String, Color)] {
        [
            ("shield","Crème solaire","SPF \(store.profile.phototype.recommendedSPF)","À remettre toutes les 2h", Palette.terra),
            ("ruler","Position","Allongé·e à plat","Retourne-toi à mi-temps", Palette.bronze),
            ("drop","Après le soleil","After-sun","Dans l'heure qui suit", Palette.amberDeep)
        ]
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Icon(name: "chevL", size: 20).foregroundStyle(Palette.inkOn)
                                .frame(width: 46, height: 46).background(Circle().fill(Palette.ink))
                        }.buttonStyle(.plain)
                        Spacer()
                        UvBadge(uv: forecast.current)
                    }
                    .padding(.top, 4)

                    Eyebrow(text: "Recommandation du jour").padding(.top, 12)
                    ScreenTitle(text: "Ton temps\nde soleil").padding(.top, 8)

                    VStack(spacing: 0) {
                        Eyebrow(text: "Aujourd'hui, tu peux bronzer")
                        (Text("\(safeMin)").font(SolaFont.display(56, weight: .heavy))
                         + Text("min").font(SolaFont.display(22, weight: .heavy)))
                            .foregroundStyle(Palette.ink).padding(.top, 4)
                        Text("sans risque de coup de soleil, pour ta peau (type \(store.profile.phototype.roman))")
                            .font(SolaFont.body(13.5)).foregroundStyle(Palette.ink2).padding(.top, 2)
                        HStack(spacing: 14) {
                            doseTile("\(perFace) min", "par face")
                            doseTile("1×", "retournement")
                        }
                        .padding(.top, 14)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.tintAmber, Palette.tintGold], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .padding(.top, 12)

                    VStack(spacing: 8) {
                        ForEach(Array(params.enumerated()), id: \.offset) { _, p in
                            CardBox(padding: 11) {
                                HStack(spacing: 14) {
                                    Icon(name: p.0, size: 20).foregroundStyle(p.4)
                                        .frame(width: 38, height: 38)
                                        .background(GlassPanel(radius: 13, tint: Palette.bgWarm, tintOpacity: 0.30))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.1).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
                                        Text(p.2).font(SolaFont.body(16, weight: .bold))
                                    }
                                    Spacer(minLength: 0)
                                    Text(p.3).font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)

                    CardBox(fill: Color(oklch: 0.93, 0.055, 32), padding: 14, shadow: false) {
                        HStack(spacing: 14) {
                            Icon(name: "flame", size: 20).foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(GlassPanel(radius: 13, tint: Palette.alert, tintOpacity: 0.66))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Limite à \(limitTime)").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.alert)
                                Text("Rentre à l'ombre après ce créneau.").font(SolaFont.body(13))
                                    .foregroundStyle(Color(oklch: 0.50, 0.10, 32))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.top, 12)

                    PillLabelButton(title: "Lancer le minuteur", icon: "timer") { showTimer = true }
                        .padding(.top, 12)
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await forecastStore.loadIfNeeded(lat: store.profile.latitude, lon: store.profile.longitude, city: store.profile.city) }
        .fullScreenCover(isPresented: $showTimer) {
            ExposureTimerView(safeMinutes: safeMin, uv: forecast.current)
        }
    }
    private func doseTile(_ num: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(num).font(SolaFont.display(18, weight: .heavy)).foregroundStyle(Palette.ink)
            Text(label).font(SolaFont.body(11.5)).foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.6)))
    }
}

// MARK: - Minuteur d'exposition (plein écran)
struct ExposureTimerView: View {
    let safeMinutes: Int
    let uv: Double
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var timer = ExposureTimer()
    @State private var usedSPF = true
    @State private var logged = false
    @State private var flipped = false

    /// Progression d'indice gagnée par cette session (même barème que sessionsContribution : ~1 pt / 8 min).
    private var sessionGain: Int { min(60, max(1, Int(timer.elapsed / 60)) / 8) }

    var body: some View {
        ScreenScaffold(
            background: LinearGradient(colors: [
                Color(oklch: 0.46, 0.09, 54), Color(oklch: 0.24, 0.04, 50)
            ], startPoint: .top, endPoint: .bottom),
            lightStatusBar: true
        ) {
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Icon(name: "chevD", size: 22).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(Circle().fill(.white.opacity(0.18)))
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("DOSE SÛRE · \(safeMinutes) MIN").font(SolaFont.mono(11)).tracking(1).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                ZStack {
                    Circle().stroke(.white.opacity(0.15), lineWidth: 18).frame(width: 240, height: 240)
                    Circle().trim(from: 0, to: timer.progress)
                        .stroke(timer.finished ? Palette.alert : Palette.gold,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 240, height: 240)
                        .animation(.linear(duration: 0.2), value: timer.progress)
                    VStack(spacing: 6) {
                        if timer.finished {
                            Text("TERMINÉ").font(SolaFont.display(34, weight: .heavy)).foregroundStyle(.white)
                            Text("+\(sessionGain) pts d'indice")
                                .font(SolaFont.dataSmall).foregroundStyle(Palette.gold)
                            Text("Mets-toi à l'ombre").font(SolaFont.body(14)).foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text(timer.remainingLabel)
                                .font(SolaFont.display(52, weight: .heavy)).foregroundStyle(.white)
                            Text("restant").font(SolaFont.body(14)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // Alerte retournement à mi-parcours (in-app)
                if !timer.finished && timer.running && timer.progress >= 0.5 && !flipped {
                    HStack(spacing: 10) {
                        Icon(name: "refresh", size: 16).foregroundStyle(Palette.gold)
                        Text("Mi-parcours — retourne-toi").font(SolaFont.body(14, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        Button { flipped = true } label: {
                            Text("OK").font(SolaFont.body(13, weight: .bold)).foregroundStyle(Palette.onAmber)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Capsule().fill(Palette.gold))
                        }.buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.10)))
                    .padding(.top, 16)
                    .transition(.opacity)
                }

                Spacer()
                Toggle(isOn: $usedSPF) {
                    HStack(spacing: 10) {
                        Icon(name: "shield", size: 18).foregroundStyle(Palette.gold)
                        Text("Crème solaire appliquée").font(SolaFont.body(15, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .tint(Palette.amberDeep)
                .padding(.horizontal, 20).frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                .padding(.bottom, 14)

                if timer.finished {
                    SolaButton(title: "Enregistrer la session", kind: .amber, icon: "check") { logSession() }
                } else if timer.running {
                    SolaButton(title: "Mettre en pause", kind: .light, icon: nil) { timer.pause() }
                } else {
                    SolaButton(title: timer.elapsed > 0 ? "Reprendre" : "Démarrer", kind: .amber, icon: "timer") {
                        startTimer()
                    }
                }
            }
            .padding(.horizontal, Frame.padH).padding(.top, 8).padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.25), value: timer.progress >= 0.5)
        }
        .onAppear {
            timer.configure(minutes: safeMinutes)
            // Pré-coche la crème selon l'habitude déclarée (0 = jamais).
            usedSPF = store.profile.spfHabit > 0
        }
        .onChange(of: timer.finished) { _, done in
            if done {
                HapticsManager.shared.success()
                if store.data.notifPrefs.burnAlerts { notifications.scheduleBurnAlert(after: 1) }
                // Seuil atteint : termine la Live Activity sur l'état final « couvre-toi ».
                LiveActivityManager.shared.end(reached: true)
            }
        }
        .onChange(of: timer.progress) { _, p in
            // Met à jour la Live Activity (progression début → seuil de risque).
            if timer.running {
                LiveActivityManager.shared.update(
                    progress: p,
                    endDate: Date().addingTimeInterval(timer.remaining),
                    paused: false)
            }
        }
        .onChange(of: timer.running) { _, running in
            // Reflète la pause/reprise dans la Live Activity (sans la terminer).
            if !running && !timer.finished {
                LiveActivityManager.shared.update(
                    progress: timer.progress,
                    endDate: Date().addingTimeInterval(timer.remaining),
                    paused: true)
            }
        }
        .onChange(of: timer.progress >= 0.5) { _, crossed in
            if crossed && !flipped && timer.running { HapticsManager.shared.warning() }
        }
        .onDisappear {
            // Si l'utilisateur quitte avant le seuil, on clôt proprement (sans état « atteint »).
            if !timer.finished { LiveActivityManager.shared.end(reached: false) }
        }
    }

    private func startTimer() {
        timer.start()
        let prefs = store.data.notifPrefs
        let spf = store.profile.phototype.recommendedSPF
        if usedSPF && prefs.spfReminders { notifications.scheduleSPFReminder(spf: spf) }
        if prefs.burnAlerts { notifications.scheduleBurnAlert(after: timer.remaining) }
        // Alerte retournement à mi-parcours.
        notifications.scheduleFlipAlert(after: timer.remaining / 2)
        // Rappel proactif : ~10 min avant le plafond (si la session est assez longue).
        let lead = TimeInterval(Alerts.burnLeadMinutes * 60)
        if prefs.burnAlerts && timer.remaining > lead {
            notifications.scheduleBurnRiskAlert(inMinutes: Alerts.burnLeadMinutes,
                                                after: timer.remaining - lead)
        }
        // Alerte « risque élevé » à ~80 % du temps sûr.
        if prefs.burnAlerts {
            let at = timer.total * Alerts.doseWarnFraction
            let remainAtThreshold = Int((timer.total - at) / 60)
            notifications.scheduleDoseThresholdAlert(remainingMinutes: remainAtThreshold, after: at)
        }
        // Live Activity « Sun exposure » : compte à rebours vers le seuil de risque.
        LiveActivityManager.shared.start(
            city: store.profile.city, uv: uv, safeMinutes: safeMinutes,
            endDate: Date().addingTimeInterval(timer.remaining))
    }

    private func logSession() {
        guard !logged else { dismiss(); return }
        logged = true
        let minutes = max(1, Int(timer.elapsed / 60))
        store.addSession(TanSession(durationMinutes: minutes, usedSPF: usedSPF, uvIndex: uv,
                                    note: "Session d'exposition"))
        dismiss()
    }
}

// MARK: - A6 · Journal
struct AppHistory: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var purchases: PurchaseManager
    @State private var picked: UIImage?
    @State private var showPicker = false
    @State private var showPaywall = false

    // Essai gratuit : ajout de photos illimité.
    private var canAddPhoto: Bool { true }
    private func requestPhoto() {
        if canAddPhoto { showPicker = true } else { showPaywall = true }
    }

    private let toneColors = [
        Palette.lineSoft, Palette.tintAmber, Color(oklch: 0.84, 0.06, 66),
        Color(oklch: 0.74, 0.08, 62), Color(oklch: 0.62, 0.09, 58)
    ]
    private var photos: [TanSession] { Array(store.lastPhotoSessions.suffix(3)) }
    private var sessionCount: Int { store.data.sessions.filter { $0.durationMinutes > 0 }.count }
    private var totalSunLabel: String {
        let m = store.data.sessions.reduce(0) { $0 + $1.durationMinutes }
        if m >= 60 { return "\(m / 60) h \(String(format: "%02d", m % 60))" }
        return "\(m) min"
    }
    // Assiduité de la semaine courante (lundi → dimanche) pour le strip du héros.
    private var weekStrip: [(String, Bool)] {
        let cal = Calendar.current
        let labels = ["L", "M", "M", "J", "V", "S", "D"]
        let active = Set(store.data.sessions.map { cal.startOfDay(for: $0.date) })
            .union(store.data.routineDays.filter { !$0.completed.isEmpty }
                .compactMap { AppStore.dateFromKey($0.dayKey) }.map { cal.startOfDay(for: $0) })
        let today = cal.startOfDay(for: .now)
        let weekdayIdx = (cal.component(.weekday, from: today) + 5) % 7   // 0 = lundi
        let monday = cal.date(byAdding: .day, value: -weekdayIdx, to: today)!
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: monday)!
            return (labels[i], active.contains(day))
        }
    }
    private var calendar: [[Int]] {
        // 4 dernières semaines : intensité = nb d'actions par jour (0…4)
        let cal = Calendar.current
        var grid: [[Int]] = []
        for w in (0..<4).reversed() {
            var row: [Int] = []
            for d in 0..<7 {
                let offset = -(w * 7 + (6 - d))
                guard let day = cal.date(byAdding: .day, value: offset, to: .now) else { row.append(0); continue }
                let key = AppStore.dayKey(day)
                let routineCount = store.data.routineDays.first { $0.dayKey == key }?.completed.count ?? 0
                let sessionCount = store.data.sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.count
                row.append(min(4, routineCount + sessionCount))
            }
            grid.append(row)
        }
        return grid
    }
    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            ScreenTitle(text: "Ton journal")
                            Text("Chaque jour au soleil compte")
                                .font(SolaFont.body(13.5)).foregroundStyle(Palette.ink3)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Série — l'ancre de motivation, avec l'assiduité de la semaine.
                    SunHero(showMotif: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                ClayAssetImage(name: ClayIMG.flame, size: 54)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(store.streak > 0 ? "\(store.streak) jour\(store.streak > 1 ? "s" : "")" : "À démarrer")
                                        .font(SolaFont.display(31, weight: .heavy)).foregroundStyle(Palette.ink)
                                    Text(store.streak > 0 ? "de série — continue !" : "lance ta première séance")
                                        .font(SolaFont.body(13.5, weight: .semibold)).foregroundStyle(Palette.ink2)
                                }
                                Spacer(minLength: 0)
                            }
                            HStack(spacing: 6) {
                                ForEach(Array(weekStrip.enumerated()), id: \.offset) { _, d in
                                    VStack(spacing: 5) {
                                        GlassPanel(radius: 11,
                                                   tint: d.1 ? Palette.amber : Palette.surface,
                                                   tintOpacity: d.1 ? 0.58 : 0.26)
                                            .frame(height: 34)
                                        Text(d.0).font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)

                    // Bento : temps au soleil cumulé + nombre de séances.
                    HStack(spacing: 12) {
                        BentoTile(clay: ClayIMG.sun, label: "Temps au soleil", value: totalSunLabel)
                        BentoTile(clay: ClayIMG.timer, label: "Séances", value: "\(sessionCount)")
                    }
                    .padding(.top, 12)

                    CardBox {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Indice de bronzage").font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3)
                                    Text("\(store.currentTanIndex)%").font(SolaFont.display(36, weight: .heavy)).foregroundStyle(Palette.ink).padding(.top, 4)
                                }
                                Spacer()
                                // Tendance réelle : gain depuis le début de la série affichée (7 sem.).
                                // Sans données, on n'affiche pas de « +0 » trompeur mais un état initial.
                                if store.hasTanData {
                                    Badge(text: "+\(max(0, store.currentTanIndex - Int(store.weeklySeries.first ?? 0))) en 7 sem.", icon: "arrowUp", style: .amber)
                                } else {
                                    Badge(text: "À mesurer", icon: "sparkle", style: .normal)
                                }
                            }
                            BarsChart(values: store.weeklySeries, peakIndex: store.weeklySeries.count - 1, height: 96).padding(.top, 18)
                            HStack {
                                ForEach(["S1","S2","S3","S4","S5","S6","S7"], id: \.self) { w in
                                    Text(w).font(SolaFont.mono(10)).foregroundStyle(Palette.ink3).frame(maxWidth: .infinity)
                                }
                            }.padding(.top, 8)
                        }
                    }
                    .padding(.top, 16)

                    HStack {
                        Text("Suivi photo").font(SolaFont.display(20, weight: .bold)).tracking(-0.3)
                        Spacer()
                        Button { requestPhoto() } label: {
                            HStack(spacing: 6) { Icon(name: "plus", size: 14); Text("Ajouter") }
                                .font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.bronze)
                        }.buttonStyle(.plain)
                    }
                    .padding(.top, 20).padding(.bottom, 12)
                    if photos.isEmpty {
                        // État vide engageant : un seul CTA clair plutôt que 3 caméras grises.
                        Button { requestPhoto() } label: {
                            CardBox(fill: Palette.tintAmber, padding: 18, borderColor: Palette.line) {
                                HStack(spacing: 14) {
                                    Icon(name: "camera", size: 24).foregroundStyle(Palette.onAmber)
                                        .frame(width: 52, height: 52)
                                        .background(GlassPanel(radius: 16, tint: Palette.amber, tintOpacity: 0.62))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Prends ta première photo")
                                            .font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                                        Text("Démarre ton suivi : tu compareras ton avant/après au fil des semaines.")
                                            .font(SolaFont.body(13)).foregroundStyle(Palette.ink3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Icon(name: "chevR", size: 18).foregroundStyle(Palette.ink3)
                                }
                            }
                        }.buttonStyle(.plain)
                    } else {
                        HStack(spacing: 14) {
                            ForEach(photos) { s in
                                VStack(spacing: 8) {
                                    Group {
                                        if let n = s.photoFilename, let img = PhotoStore.load(n) {
                                            Image(uiImage: img).resizable().scaledToFill()
                                        } else { StripedPlaceholder(tone: .warm) }
                                    }
                                    .frame(height: 132).frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    Text(relativeDay(s.date)).font(SolaFont.mono(11)).foregroundStyle(Palette.ink3)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    CardBox {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Assiduité").font(SolaFont.body(16, weight: .bold))
                                Spacer()
                                // Série réelle ; sans aucun jour actif, on invite à démarrer
                                // plutôt que d'afficher « série de 0 j ».
                                if store.streak > 0 {
                                    Badge(text: "série de \(store.streak) j", icon: "flame", style: .amber)
                                } else {
                                    Badge(text: "À démarrer", icon: "flame", style: .normal)
                                }
                            }.padding(.bottom, 14)
                            VStack(spacing: 6) {
                                ForEach(Array(calendar.enumerated()), id: \.offset) { _, row in
                                    HStack(spacing: 6) {
                                        ForEach(Array(row.enumerated()), id: \.offset) { _, lvl in
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(toneColors[min(lvl, toneColors.count - 1)]).aspectRatio(1, contentMode: .fit)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)

                    // Insights mémoire (B4)
                    InsightsSection(insights: Insights.derive(
                        from: store.data.sessions,
                        planStart: store.profile.planStartDate,
                        currentIndex: store.currentTanIndex,
                        baseline: store.profile.baselineIndex))
                        .padding(.top, 20)

                    TabBarSpacer()
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showPicker) { CameraPhotoPicker(image: $picked) }
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
        .onChange(of: picked) { _, img in
            if let img, let name = PhotoStore.save(img) {
                store.addSession(TanSession(durationMinutes: 0, usedSPF: false, uvIndex: 0,
                                            note: "Suivi photo", photoFilename: name))
            }
        }
    }
    private func relativeDay(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: store.profile.planStartDate, to: date).day ?? 0
        return "J-\(max(0, days))"
    }
}

// MARK: - A7 · Profil
struct AppProfile: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Goldn · v\(v) (\(b))"
    }

    private var tiles: [(HomeRoute, String, String)] {
        [(.skin, ClayIMG.skinPalette, "Ma peau"),
         (.settings, ClayIMG.settings, "Réglages")]
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        ScreenTitle(text: "Profil")
                        Spacer()
                    }
                    .padding(.top, 4)

                    SunHero(showMotif: false) {
                        HStack(spacing: 15) {
                            AvatarView(size: 64)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.profile.name.isEmpty ? "Mon profil" : store.profile.name)
                                    .font(SolaFont.display(22, weight: .heavy)).tracking(-0.5).foregroundStyle(Palette.ink)
                                HStack(spacing: 8) {
                                    Badge(text: "Phototype \(store.profile.phototype.roman)", style: .amber)
                                    Badge(text: purchases.isPro ? "Goldn+" : "Gratuit")
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.top, 12)

                    if !purchases.isPro {
                        Button { showPaywall = true } label: {
                            CardBox(fill: Palette.ink, padding: 16) {
                                HStack(spacing: 14) {
                                    Icon(name: "sparkle", size: 22).foregroundStyle(Palette.onAmber)
                                        .frame(width: 44, height: 44)
                                        .background(GlassPanel(radius: 14, tint: Palette.gold, tintOpacity: 0.58))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Passe à Goldn+").font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.inkOn)
                                        Text("Analyses & suivi photo illimités").font(SolaFont.body(13)).foregroundStyle(Palette.inkOn.opacity(0.7))
                                    }
                                    Spacer(minLength: 0)
                                    Icon(name: "chevR", size: 18).foregroundStyle(Palette.inkOn.opacity(0.7))
                                }
                            }
                        }.buttonStyle(.plain)
                        .padding(.top, 12)
                    }

                    // Hub : cartes horizontales en liquid glass, le détail est en sous-pages.
                    SectionHeader("Explorer").padding(.top, 16).padding(.bottom, 10)
                    VStack(spacing: 9) {
                        ForEach(Array(tiles.enumerated()), id: \.offset) { _, t in
                            glassRow(route: t.0, clayIcon: t.1, title: t.2)
                        }
                    }

                    // Pied de page : achats, contact, mentions, version.
                    VStack(spacing: 13) {
                        Button { Task { await purchases.restore() } } label: {
                            Text("Restaurer mes achats")
                                .font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink2)
                        }
                        Button { openURL(URL(string: "mailto:contact@meflabs.com")!) } label: {
                            Text("Nous contacter")
                                .font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink2)
                        }
                        HStack(spacing: 16) {
                            Button { openURL(URL(string: "https://goldnapp.com/terms")!) } label: {
                                Text("Conditions").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                            }
                            Button { openURL(URL(string: "https://goldnapp.com/privacy")!) } label: {
                                Text("Confidentialité").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                            }
                            Button { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) } label: {
                                Text("EULA").font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                            }
                        }
                        Text(appVersion)
                            .font(SolaFont.body(11)).foregroundStyle(Palette.ink3)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 8)

                    TabBarSpacer()
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .profile: AppProfile()
            case .skin: AppProfileSkin()
            case .reco: AppReco()
            case .uv: AppUV()
            case .achievements: AppAchievements()
            case .analytics: AnalyticsDashboard()
            case .personalization: AppPersonalization()
            case .settings: AppProfileSettings()
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
    }

    // Carte horizontale du hub en liquid glass (icône clay + libellé + chevron).
    private func glassRow(route: HomeRoute, clayIcon: String, title: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                ClayAssetImage(name: clayIcon, size: 32, shadow: false)
                    .frame(width: 42, height: 42)
                    .background(GlassCircle(tint: Palette.bgWarm, tintOpacity: 0.34))
                Text(title).font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Icon(name: "chevR", size: 18).foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(GlassPanel(radius: Radius.lg, tint: Palette.surface, tintOpacity: 0.30))
        }.buttonStyle(.plain)
    }
}

// MARK: - A7c · Réglages (sous-page du profil = paramètres fusionnés)
struct AppProfileSettings: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var flow: AppFlow
    @EnvironmentObject var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var name: String = ""
    @State private var confirmReset = false

    // Version réelle (CFBundleShortVersionString), avec le build entre parenthèses.
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconButton(icon: "chevL", iconSize: 20) { dismiss() }
                        ScreenTitle(text: "Réglages")
                        Spacer()
                    }
                    .padding(.top, 4)

                    SectionHeader("Compte").padding(.top, 16).padding(.bottom, 10)
                    CardBox(padding: 14, shadow: false, borderColor: Palette.lineSoft) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prénom").font(SolaFont.body(12, weight: .semibold)).foregroundStyle(Palette.ink3)
                            TextField("Ton prénom", text: $name)
                                .font(SolaFont.body(16, weight: .bold)).foregroundStyle(Palette.ink)
                                .submitLabel(.done)
                                .onSubmit { store.profile.name = name }
                        }
                    }
                    if !purchases.isPro {
                        Button { Task { await purchases.restore() } } label: {
                            settingsRow(icon: "crown", title: "Restaurer mes achats", trailingChevron: true)
                        }.buttonStyle(.plain).padding(.top, 7)
                    }

                    SectionHeader("Réglages").padding(.top, 18).padding(.bottom, 10)
                    VStack(spacing: 7) {
                        toggleRow(title: "Rappels SPF", subtitle: "Renouvellement de protection",
                                  isOn: Binding(get: { store.data.notifPrefs.spfReminders },
                                                set: { store.data.notifPrefs.spfReminders = $0 }))
                        toggleRow(title: "Fenêtre UV idéale", subtitle: "Au meilleur créneau d'exposition",
                                  isOn: Binding(get: { store.data.notifPrefs.uvWindow },
                                                set: { store.data.notifPrefs.uvWindow = $0 }))
                        toggleRow(title: "Alertes de brûlure", subtitle: "Quand tu approches ton seuil",
                                  isOn: Binding(get: { store.data.notifPrefs.burnAlerts },
                                                set: { store.data.notifPrefs.burnAlerts = $0 }))
                    }
                    .padding(.top, 7)
                    if !notifications.authorized {
                        Button { Task { _ = await notifications.requestAuthorization() } } label: {
                            settingsRow(icon: "alertTri", title: "Autoriser les notifications", trailingChevron: true)
                        }.buttonStyle(.plain).padding(.top, 7)
                    }
                    Button { flow.restart() } label: {
                        settingsRow(icon: "refresh", title: "Refaire le test phototype", trailingChevron: true)
                    }.buttonStyle(.plain).padding(.top, 7)

                    SectionHeader("À propos").padding(.top, 18).padding(.bottom, 10)
                    VStack(spacing: 7) {
                        settingsRow(icon: "info", title: "Version", trailing: Self.appVersion)
                        Button { openURL(URL(string: "https://goldnapp.com/terms")!) } label: {
                            settingsRow(icon: "book", title: "Conditions d'utilisation", trailingChevron: true)
                        }.buttonStyle(.plain)
                        Button { openURL(URL(string: "https://goldnapp.com/privacy")!) } label: {
                            settingsRow(icon: "shield", title: "Politique de confidentialité", trailingChevron: true)
                        }.buttonStyle(.plain)
                        Button { openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) } label: {
                            settingsRow(icon: "book", title: "Licence d'utilisation (EULA)", trailingChevron: true)
                        }.buttonStyle(.plain)
                    }

                    Button { confirmReset = true } label: {
                        HStack(spacing: 14) {
                            Icon(name: "trash", size: 18).foregroundStyle(Palette.alert)
                            Text("Réinitialiser l'application").font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.alert)
                            Spacer(minLength: 0)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(GlassPanel(radius: Radius.md, tint: Palette.alert, tintOpacity: 0.14))
                    }.buttonStyle(.plain).padding(.top, 18)

                    TabBarSpacer()
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { name = store.profile.name }
        .alert("Tout réinitialiser ?", isPresented: $confirmReset) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) { store.resetAll(); flow.restart() }
        } message: {
            Text("Supprime ton profil, tes sessions et tes photos. Action irréversible.")
        }
    }

    // Ligne de réglage avec interrupteur.
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        CardBox(padding: 12, shadow: false, borderColor: Palette.lineSoft) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(SolaFont.body(12)).foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: isOn).labelsHidden().tint(Palette.amberDeep)
            }
        }
    }

    // Ligne d'action / info (icône + titre + valeur ou chevron).
    private func settingsRow(icon: String, title: String, trailing: String? = nil, trailingChevron: Bool = false) -> some View {
        CardBox(padding: 12, shadow: false, borderColor: Palette.lineSoft) {
            HStack(spacing: 14) {
                Icon(name: icon, size: 18).foregroundStyle(Palette.ink2)
                Text(title).font(SolaFont.body(15, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                if let trailing { Text(trailing).font(SolaFont.body(14)).foregroundStyle(Palette.ink3) }
                if trailingChevron { Icon(name: "chevR", size: 16).foregroundStyle(Palette.ink3) }
            }
        }
    }
}

// MARK: - A7b · Ma peau (sous-page du profil)
struct AppProfileSkin: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var stats: [(String, String, String)] {
        let p = store.profile
        return [
            ("Phototype", p.phototype.roman, ClayIMG.skinPalette),
            ("Seuil rougeur", "~\(p.phototype.safeMinutesAtUV8) min", ClayIMG.timer),
            ("SPF conseillé", "\(p.phototype.recommendedSPF)", ClayIMG.shield),
            ("Objectif", p.goal.title, ClayIMG.sun)
        ]
    }
    // Récapitulatif des réponses d'onboarding (sinon inexploitées).
    private static let frequencyLabels = ["Tous les jours","Plusieurs fois/sem.","Le week-end","En vacances"]
    private static let placeLabels = ["Plage","Piscine","Jardin","Cabine UV","Autobronzant","Montagne"]
    private static let concernLabels = ["Coups de soleil","Vieillissement","Taches","Bronzage irrégulier"]
    private var habitTags: [String] {
        let p = store.profile
        var tags: [String] = []
        if Self.frequencyLabels.indices.contains(p.frequency) { tags.append(Self.frequencyLabels[p.frequency]) }
        tags += p.places.sorted().compactMap { Self.placeLabels.indices.contains($0) ? Self.placeLabels[$0] : nil }
        tags += p.concerns.sorted().compactMap { Self.concernLabels.indices.contains($0) ? Self.concernLabels[$0] : nil }
        return tags
    }

    var body: some View {
        ScreenScaffold(background: Palette.bg) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconButton(icon: "chevL", iconSize: 20) { dismiss() }
                        ScreenTitle(text: "Ma peau")
                        Spacer()
                    }
                    .padding(.top, 4)

                    SectionHeader("Ta peau").padding(.top, 16).padding(.bottom, 10)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { _, s in
                            CardBox(padding: 11) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ClayAssetImage(name: s.2, size: 30, shadow: false)
                                    Text(s.1).font(SolaFont.display(20, weight: .heavy)).foregroundStyle(Palette.ink).padding(.top, 5)
                                        .lineLimit(1).minimumScaleFactor(0.6)
                                    Text(s.0).font(SolaFont.body(13, weight: .semibold)).foregroundStyle(Palette.ink3).padding(.top, 1)
                                }
                            }
                        }
                    }

                    if !habitTags.isEmpty {
                        SectionHeader("Tes habitudes").padding(.top, 18).padding(.bottom, 10)
                        FlowTags(tags: habitTags)
                    }
                    TabBarSpacer()
                }
                .padding(.horizontal, Frame.padH)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// Disposition « flow » : tags qui passent à la ligne automatiquement.
struct FlowTags: View {
    let tags: [String]
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { Badge(text: $0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

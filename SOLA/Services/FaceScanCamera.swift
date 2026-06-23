import SwiftUI
import UIKit
import AVFoundation
import Vision

// MARK: - État de cadrage en direct
enum FramingState: Equatable {
    case searching, tooClose, tooFar, offCenter, good

    var message: String {
        switch self {
        case .searching: return "Place ton visage dans le cadre"
        case .tooClose:  return "Recule un peu"
        case .tooFar:    return "Rapproche ton visage"
        case .offCenter: return "Centre ton visage"
        case .good:      return "Parfait — ne bouge plus"
        }
    }
    var isGood: Bool { self == .good }
}

// MARK: - Pont SwiftUI ↔ caméra
@MainActor
final class FaceScanModel: ObservableObject {
    @Published var state: FramingState = .searching
    fileprivate weak var controller: FaceScanVC?
    /// Capture manuelle (bouton déclencheur).
    func shutter() { controller?.capturePhoto() }
}

/// Caméra avant + détection de visage en direct : guide le cadrage et capture
/// automatiquement (ou au tap) quand le visage est bien positionné.
struct FaceScanCamera: UIViewControllerRepresentable {
    @ObservedObject var model: FaceScanModel
    var autoCapture: Bool = true
    var onCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> FaceScanVC {
        let vc = FaceScanVC()
        vc.autoCapture = autoCapture
        vc.onState = { [weak model] s in model?.state = s }
        vc.onCaptured = onCaptured
        model.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: FaceScanVC, context: Context) {
        vc.autoCapture = autoCapture
    }

    static func hasFrontCamera() -> Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }
}

// MARK: - Contrôleur AVFoundation
final class FaceScanVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    var onState: (FramingState) -> Void = { _ in }
    var onCaptured: (UIImage) -> Void = { _ in }
    var autoCapture = true

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let queue = DispatchQueue(label: "sola.facescan.video")
    private var goodStreak = 0
    private var goodSince: Date?
    private var didCapture = false
    private var lastState: FramingState = .searching

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                guard ok else { return }
                DispatchQueue.main.async { self?.configureSession(); self?.start() }
            }
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); start() }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); stop() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); previewLayer?.frame = view.bounds }

    private func start() { if previewLayer != nil { queue.async { if !self.session.isRunning { self.session.startRunning() } } } }
    private func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    private func configureSession() {
        guard previewLayer == nil else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        start()
    }

    // MARK: Détection live
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .leftMirrored, options: [:])
        try? handler.perform([request])
        let state = Self.evaluate(request.results ?? [])
        DispatchQueue.main.async { self.apply(state) }
    }

    private static func evaluate(_ faces: [VNFaceObservation]) -> FramingState {
        guard let face = faces.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return .searching }
        let box = face.boundingBox
        if box.height > 0.86 { return .tooClose }
        if box.height < 0.40 { return .tooFar }
        if box.midX < 0.30 || box.midX > 0.70 || box.midY < 0.28 || box.midY > 0.74 { return .offCenter }
        return .good
    }

    private func apply(_ state: FramingState) {
        if state != lastState { lastState = state; onState(state) }
        if state == .good {
            if goodSince == nil { goodSince = Date() }
            goodStreak += 1
        } else {
            goodSince = nil
            goodStreak = 0
        }
        let stableLongEnough = goodSince.map { Date().timeIntervalSince($0) >= 1.0 } ?? false
        if autoCapture, stableLongEnough, goodStreak >= 8, !didCapture { capturePhoto() }
    }

    // MARK: Capture
    func capturePhoto() {
        guard !didCapture, session.isRunning else { return }
        didCapture = true
        if let conn = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            didCapture = false; return
        }
        DispatchQueue.main.async { self.onCaptured(image) }
    }
}

// MARK: - Écran de scan (caméra + guidage + déclencheur)
struct FaceScanScreen: View {
    var onCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    var onPickLibrary: () -> Void = {}

    @StateObject private var model = FaceScanModel()
    @State private var captured = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if FaceScanCamera.hasFrontCamera() {
                FaceScanCamera(model: model, autoCapture: true) { img in
                    guard !captured else { return }
                    captured = true
                    onCaptured(img)
                }
                .ignoresSafeArea()
                overlay
            } else {
                noCamera
            }
        }
    }

    private var overlay: some View {
        GeometryReader { geo in
            let boxW = min(geo.size.width * 0.74, 320)
            let boxH = boxW * 1.32
            let cy = geo.size.height * 0.44
            ZStack {
                // Cadre cible (devient vert quand le cadrage est bon)
                ReticleCorners(cornerLength: 34, radius: 28)
                    .stroke(model.state.isGood ? Palette.success : .white.opacity(0.95),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: boxW, height: boxH)
                    .position(x: geo.size.width / 2, y: cy)
                    .shadow(color: .black.opacity(0.4), radius: 6)
                    .animation(.easeInOut(duration: 0.25), value: model.state)

                // Consigne au-dessus du cadre
                guidancePill
                    .position(x: geo.size.width / 2, y: max(80, cy - boxH / 2 - 42))
                    .animation(.easeInOut(duration: 0.2), value: model.state)

                // Header (fermer + titre)
                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Icon(name: "cross", size: 18, stroke: 2.4).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.16)))
                        }.buttonStyle(.plain)
                        Spacer()
                        Text("Scanne ta peau").font(SolaFont.display(19, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    // Déclencheur manuel + photothèque
                    HStack {
                        Button(action: onPickLibrary) {
                            Icon(name: "camera", size: 20).foregroundStyle(.white)
                                .frame(width: 50, height: 50).background(Circle().fill(.white.opacity(0.16)))
                        }.buttonStyle(.plain)
                        Spacer()
                        Button { model.shutter() } label: {
                            Circle().fill(.white).frame(width: 74, height: 74)
                                .overlay(Circle().stroke(model.state.isGood ? Palette.success : .white.opacity(0.6), lineWidth: 4)
                                    .frame(width: 84, height: 84))
                        }.buttonStyle(.plain)
                        Spacer()
                        Color.clear.frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, Frame.padH)
                .padding(.top, 8)
                .padding(.bottom, 26)
                .frame(maxWidth: Frame.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var guidancePill: some View {
        HStack(spacing: 9) {
            Circle().fill(model.state.isGood ? Palette.success : Palette.gold).frame(width: 8, height: 8)
            Text(model.state.message)
                .font(SolaFont.body(15, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.55)))
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
    }

    private var noCamera: some View {
        VStack(spacing: 18) {
            Text("Caméra indisponible")
                .font(SolaFont.display(22, weight: .bold)).foregroundStyle(.white)
            Text("Importe plutôt une photo depuis ta photothèque.")
                .font(SolaFont.body(14)).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(action: onPickLibrary) {
                Text("Choisir une photo").font(SolaFont.body(15, weight: .semibold))
                    .foregroundStyle(Palette.onAmber)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Palette.gold))
            }.buttonStyle(.plain)
            Button("Annuler", action: onCancel)
                .font(SolaFont.body(14)).foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
    }
}

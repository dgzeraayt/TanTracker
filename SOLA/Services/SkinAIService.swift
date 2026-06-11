import Foundation
import UIKit

// MARK: - Configuration du proxy backend (Vercel)
// La clé OpenAI vit UNIQUEMENT côté serveur (sola-api). L'app ne connaît que
// l'URL du proxy + un token partagé d'accès (anti-abus), jamais la clé OpenAI.
enum SkinAPIConfig {
    /// URL de base du proxy. À remplacer par ton déploiement après `vercel deploy`.
    static let baseURL = "https://sola-api.vercel.app"

    /// Token partagé (doit correspondre à SOLA_API_TOKEN côté Vercel).
    /// Lu depuis l'environnement en dev (SIMCTL_CHILD_SOLA_API_TOKEN), sinon
    /// la constante de repli ci-dessous.
    static var token: String {
        if let env = ProcessInfo.processInfo.environment["SOLA_API_TOKEN"], !env.isEmpty { return env }
        return "REPLACE_WITH_SOLA_API_TOKEN"
    }

    static var endpoint: URL? { URL(string: baseURL + "/api/analyze-skin") }
}

// MARK: - Erreurs d'analyse IA
enum SkinAIError: LocalizedError {
    case notConfigured
    case imageEncoding
    case network
    case api(status: Int, message: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured:     return "Proxy d'analyse non configuré."
        case .imageEncoding:     return "La photo n'a pas pu être préparée."
        case .network:           return "Réseau indisponible."
        case .api(let s, let m): return "Le serveur a renvoyé une erreur (\(s))." + (m.map { " \($0)" } ?? "")
        case .decoding:          return "Réponse du serveur illisible."
        }
    }
}

// MARK: - Analyse de peau via le proxy backend (OpenAI vision côté serveur)
enum SkinAIService {
    /// Analyse IA + repli on-device : essaie le proxy, retombe sur le calcul
    /// colorimétrique local si non configuré ou si le réseau échoue. Ne lève
    /// jamais — c'est la voie utilisée par l'UI pour rester robuste hors-ligne.
    static func analyzeWithFallback(_ image: UIImage, profile: UserProfile) async -> SkinMetrics? {
        if let ai = try? await analyze(image, profile: profile) { return ai }
        return SkinAnalysis.analyze(image)
    }

    /// Appel direct au proxy. Lève en cas d'échec.
    static func analyze(_ image: UIImage, profile: UserProfile) async throws -> SkinMetrics {
        guard let endpoint = SkinAPIConfig.endpoint else { throw SkinAIError.notConfigured }
        guard let b64 = encodeImage(image) else { throw SkinAIError.imageEncoding }

        let payload: [String: Any] = [
            "imageBase64": b64,
            "mimeType": "image/jpeg",
            "phototype": profile.phototype.roman,
            "goal": profile.goal.title
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SkinAPIConfig.token, forHTTPHeaderField: "x-sola-token")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SkinAIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw SkinAIError.network }
        guard http.statusCode == 200 else {
            throw SkinAIError.api(status: http.statusCode, message: apiErrorMessage(data))
        }

        var metrics = try parseMetrics(data)
        // La position des annotations sur la photo reste calculée on-device.
        metrics.faceBox = SkinAnalysis.faceBox(in: image)
        return metrics
    }

    // MARK: Encodage image
    private static func encodeImage(_ image: UIImage, maxDimension: CGFloat = 768) -> String? {
        let longest = max(image.size.width, image.size.height)
        let ratio = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: max(1, image.size.width * ratio),
                            height: max(1, image.size.height * ratio))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }

    // MARK: Décodage réponse du proxy
    /// Le backend renvoie déjà un JSON propre et borné ; on reste tolérant
    /// (doubles ou entiers) et on reborne par sécurité côté client.
    private struct APIMetrics: Decodable {
        let tan: Double; let glow: Double; let evenness: Double; let redness: Double
        let advice: String?
    }

    private static func parseMetrics(_ data: Data) throws -> SkinMetrics {
        guard let m = try? JSONDecoder().decode(APIMetrics.self, from: data) else {
            throw SkinAIError.decoding
        }
        func clamp(_ v: Double) -> Int { Int(min(100, max(0, v)).rounded()) }
        let advice = m.advice?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SkinMetrics(tan: clamp(m.tan), glow: clamp(m.glow),
                           evenness: clamp(m.evenness), redness: clamp(m.redness),
                           faceBox: nil, sampleCount: nil,
                           advice: (advice?.isEmpty == false) ? advice : nil)
    }

    private static func apiErrorMessage(_ data: Data) -> String? {
        struct APIError: Decodable { let error: String? }
        return (try? JSONDecoder().decode(APIError.self, from: data))?.error
    }
}

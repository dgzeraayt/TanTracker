import Foundation
import Security
import UIKit

// MARK: - Stockage sécurisé de la clé API (trousseau)
// La clé OpenAI ne vit JAMAIS dans le code ni dans le binaire : l'utilisateur la
// saisit dans Réglages et elle est conservée dans le Keychain de l'appareil.
enum Keychain {
    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Configuration OpenAI
enum OpenAIConfig {
    static let keychainKey = "sola.openai.apiKey"
    /// Modèle de vision utilisé pour l'analyse de peau.
    static let model = "gpt-4o"

    /// Clé courante : trousseau en priorité, repli sur la variable d'environnement
    /// (pratique pour tester au simulateur via `SIMCTL_CHILD_OPENAI_API_KEY`).
    static var apiKey: String? {
        if let k = Keychain.get(keychainKey), !k.isEmpty { return k }
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty { return env }
        return nil
    }

    static var hasKey: Bool { apiKey?.isEmpty == false }
}

// MARK: - Erreurs d'analyse IA
enum SkinAIError: LocalizedError {
    case missingKey
    case imageEncoding
    case network
    case api(status: Int, message: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingKey:       return "Aucune clé API OpenAI configurée."
        case .imageEncoding:    return "La photo n'a pas pu être préparée."
        case .network:          return "Réseau indisponible."
        case .api(let s, let m): return "OpenAI a renvoyé une erreur (\(s))." + (m.map { " \($0)" } ?? "")
        case .decoding:         return "Réponse de l'IA illisible."
        }
    }
}

// MARK: - Analyse de peau par IA cloud (OpenAI vision)
enum SkinAIService {
    /// Analyse IA + repli on-device : essaie OpenAI, retombe sur le calcul
    /// colorimétrique local si la clé manque ou si le réseau échoue. Ne lève
    /// jamais — c'est la voie utilisée par l'UI pour rester robuste hors-ligne.
    static func analyzeWithFallback(_ image: UIImage, profile: UserProfile) async -> SkinMetrics? {
        if let ai = try? await analyze(image, profile: profile) { return ai }
        return SkinAnalysis.analyze(image)
    }

    /// Appel direct à OpenAI. Lève en cas d'échec (utile pour un test explicite
    /// dans les Réglages).
    static func analyze(_ image: UIImage, profile: UserProfile) async throws -> SkinMetrics {
        guard let apiKey = OpenAIConfig.apiKey else { throw SkinAIError.missingKey }
        guard let b64 = encodeImage(image) else { throw SkinAIError.imageEncoding }

        let body: [String: Any] = [
            "model": OpenAIConfig.model,
            "temperature": 0.2,
            "max_tokens": 400,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": [
                    ["type": "text", "text": userPrompt(profile: profile)],
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "auto"]]
                ]]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

        let content = try extractContent(data)
        var metrics = try parseMetrics(content)
        // La position des annotations sur la photo reste calculée on-device.
        metrics.faceBox = SkinAnalysis.faceBox(in: image)
        return metrics
    }

    // MARK: Prompts
    private static let systemPrompt = """
    Tu es un assistant d'analyse du teint de peau pour une application de bronzage responsable. \
    À partir d'un selfie, estime quatre mesures sur une échelle entière 0–100 :
    - "tan" : intensité du hâle/bronzage (0 = peau très claire, 100 = teinte maximale).
    - "glow" : éclat / luminosité de la peau (0 = terne, 100 = très lumineuse).
    - "evenness" : uniformité du teint (0 = très irrégulier, 100 = parfaitement uniforme).
    - "redness" : rougeur / irritation (0 = aucune, 100 = coup de soleil marqué).
    Ajoute "advice" : un conseil court (1–2 phrases) en français, ton bienveillant et préventif \
    (le bronzage doit rester sans risque de brûlure), personnalisé selon le phototype et l'objectif. \
    Réponds UNIQUEMENT en JSON strict avec exactement ces clés : tan, glow, evenness, redness, advice. \
    Aucun texte hors du JSON. Si le visage n'est pas analysable, mets des mesures plausibles et \
    explique-le dans "advice".
    """

    private static func userPrompt(profile: UserProfile) -> String {
        "Profil de l'utilisateur — phototype Fitzpatrick \(profile.phototype.roman), "
        + "objectif « \(profile.goal.title) ». Analyse ce selfie pris en lumière naturelle."
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

    // MARK: Décodage réponse
    private struct ChatResponse: Decodable {
        struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
        let choices: [Choice]
    }

    /// Tolère doubles ou entiers ; "advice" optionnel.
    private struct AIMetrics: Decodable {
        let tan: Double; let glow: Double; let evenness: Double; let redness: Double
        let advice: String?
    }

    private static func extractContent(_ data: Data) throws -> String {
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content else {
            throw SkinAIError.decoding
        }
        return content
    }

    private static func parseMetrics(_ content: String) throws -> SkinMetrics {
        // Défense : retire d'éventuels fences ```json … ``` même si json_object devrait l'éviter.
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let json = cleaned.data(using: .utf8),
              let m = try? JSONDecoder().decode(AIMetrics.self, from: json) else {
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
        struct APIError: Decodable { struct E: Decodable { let message: String }; let error: E }
        return (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
    }
}

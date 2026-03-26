import Foundation
import AgentRunKit

extension GeminiClient: LLMProvider {
    static let kind: ProviderKind = .gemini

    static let requiresAPIKey: Bool = true
    static let requiresBaseURL: Bool = false
    static let defaultBaseURL: String? = nil

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        guard let apiKey = resolveAPIKey(for: provider) else { return nil }

        return GeminiClient(
            apiKey: apiKey,
            model: model,
            maxOutputTokens: maxTokens,
            contextWindowSize: provider.contextWindowSize,
            retryPolicy: resolveRetryPolicy(from: provider),
            reasoningConfig: reasoningConfig
        )
    }

    // MARK: - Model Listing

    /// Queries the Gemini `GET /v1beta/models` endpoint for available models.
    static func listModels(for provider: Provider) async throws -> [String] {
        guard let apiKey = resolveAPIKey(for: provider) else { return [] }

        let baseURL = GeminiClient.geminiBaseURL
        let modelsURL = baseURL.appendingPathComponent("v1beta/models")

        guard var components = URLComponents(url: modelsURL, resolvingAgainstBaseURL: false) else {
            return []
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let listURL = components.url else { return [] }

        var request = URLRequest(url: listURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        struct GeminiModelsResponse: Decodable {
            struct ModelInfo: Decodable {
                let name: String
            }
            let models: [ModelInfo]
        }

        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        return decoded.models
            .map { info in
                if info.name.hasPrefix("models/") {
                    return String(info.name.dropFirst(7))
                }
                return info.name
            }
            .sorted()
    }
}

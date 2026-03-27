import Foundation
import AgentRunKit

extension GeminiClient: LLMProvider {
    static let platform: ProviderPlatform = .gemini

    static func makeClient(
        baseURL: URL?,
        apiKey: String?,
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool,
        projectID: String?,
        location: String?
    ) -> (any LLMClient)? {
        guard let apiKey else { return nil }

        return GeminiClient(
            apiKey: apiKey,
            model: model,
            maxOutputTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig
        )
    }

    // MARK: - Model Listing

    /// Queries the Gemini `GET /v1beta/models` endpoint for available models.
    static func listModels(
        baseURL: URL?,
        apiKey: String?,
        projectID: String?,
        location: String?
    ) async throws -> [String] {
        guard let apiKey else { return [] }

        let geminiBaseURL = GeminiClient.geminiBaseURL
        let modelsURL = geminiBaseURL.appendingPathComponent("v1beta/models")

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

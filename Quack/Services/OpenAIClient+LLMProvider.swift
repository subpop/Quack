import Foundation
import AgentRunKit

extension OpenAIClient: LLMProvider {
    static let kind: ProviderKind = .openAICompatible

    static let requiresAPIKey: Bool = true
    static let requiresBaseURL: Bool = true

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        let apiKey: String
        if provider.requiresAPIKey {
            guard let key = resolveAPIKey(for: provider) else { return nil }
            apiKey = key
        } else {
            apiKey = "no-key-required"
        }

        guard let baseURL = resolveBaseURL(from: provider) else { return nil }

        return OpenAIClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: provider.contextWindowSize,
            baseURL: baseURL,
            retryPolicy: resolveRetryPolicy(from: provider),
            reasoningConfig: reasoningConfig
        )
    }

    // MARK: - Model Listing

    /// Queries the OpenAI-compatible `GET /models` endpoint.
    ///
    /// Works with OpenAI, Ollama, OpenRouter, Groq, Together, and any
    /// provider that implements the OpenAI models endpoint.
    static func listModels(for provider: Provider) async throws -> [String] {
        guard let baseURL = resolveBaseURL(from: provider) else { return [] }

        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"

        if provider.requiresAPIKey, let apiKey = resolveAPIKey(for: provider) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        struct ModelsResponse: Decodable {
            struct Model: Decodable {
                let id: String
            }
            let data: [Model]
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }
}

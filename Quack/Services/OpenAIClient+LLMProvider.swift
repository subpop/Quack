import Foundation
import AgentRunKit

/// Factory and model-listing utilities for OpenAI-compatible providers.
///
/// Used by `ProviderPlatform.openAICompatible` to construct clients and fetch
/// model lists. Works with OpenAI, Ollama, OpenRouter, Groq, Together, and
/// any provider that implements the OpenAI Chat Completions API.
enum OpenAIClientFactory {

    static func makeClient(
        baseURL: URL?,
        apiKey: String?,
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool
    ) -> (any LLMClient)? {
        guard let apiKey else { return nil }
        guard let baseURL else { return nil }

        return OpenAIClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            baseURL: baseURL,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig
        )
    }

    /// Queries the OpenAI-compatible `GET /models` endpoint.
    static func listModels(
        baseURL: URL?,
        apiKey: String?
    ) async throws -> [String] {
        guard let baseURL else { return [] }

        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"

        if let apiKey {
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

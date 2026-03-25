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
}

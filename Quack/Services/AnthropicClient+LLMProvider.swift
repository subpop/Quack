import Foundation
import AgentRunKit

extension AnthropicClient: LLMProvider {
    static let kind: ProviderKind = .anthropic

    static let requiresAPIKey: Bool = true
    static let requiresBaseURL: Bool = true
    static let defaultBaseURL: String? = "https://api.anthropic.com/v1"
    static let supportsCaching: Bool = true

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        guard let apiKey = resolveAPIKey(for: provider) else { return nil }

        let baseURL = resolveBaseURL(from: provider) ?? AnthropicClient.anthropicBaseURL

        return AnthropicClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: provider.contextWindowSize,
            baseURL: baseURL,
            retryPolicy: resolveRetryPolicy(from: provider),
            reasoningConfig: reasoningConfig,
            cachingEnabled: provider.cachingEnabled
        )
    }
}

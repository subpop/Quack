import Foundation
import AgentRunKit

/// Factory utilities for Anthropic's Messages API.
///
/// Used by `ProviderPlatform.anthropic` to construct clients.
/// Anthropic does not expose a public model-listing endpoint, so
/// `ProviderPlatform.knownModels` is used as the fallback.
enum AnthropicClientFactory {

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

        let resolvedBaseURL = baseURL ?? AnthropicClient.anthropicBaseURL

        return AnthropicClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            baseURL: resolvedBaseURL,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig,
            cachingEnabled: cachingEnabled
        )
    }
}

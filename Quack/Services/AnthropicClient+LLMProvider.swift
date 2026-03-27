import Foundation
import AgentRunKit

extension AnthropicClient: LLMProvider {
    static let platform: ProviderPlatform = .anthropic

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

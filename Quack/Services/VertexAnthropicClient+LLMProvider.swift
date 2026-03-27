import Foundation
import AgentRunKit

/// Factory utilities for Anthropic Claude models on Google Cloud Vertex AI.
///
/// Used by `ProviderPlatform.vertexAnthropic` to construct clients.
/// Authenticates via Application Default Credentials through `GoogleAuthService`.
/// Anthropic does not expose a model-listing endpoint on Vertex, so
/// `ProviderPlatform.knownModels` is used as the fallback.
enum VertexAnthropicClientFactory {

    static func makeClient(
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool,
        projectID: String?,
        location: String?
    ) -> (any LLMClient)? {
        guard let projectID, !projectID.isEmpty,
              let location, !location.isEmpty else {
            return nil
        }

        guard GoogleAuthService.credentialsAvailable() else { return nil }

        guard let authService = try? GoogleAuthService() else { return nil }

        return VertexAnthropicClient(
            projectID: projectID,
            location: location,
            model: model,
            authService: authService,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig,
            cachingEnabled: cachingEnabled
        )
    }
}

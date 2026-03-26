import Foundation
import AgentRunKit

extension VertexAnthropicClient: LLMProvider {
    static let kind: ProviderKind = .vertexAnthropic

    static let requiresAPIKey: Bool = false
    static let requiresBaseURL: Bool = false
    static let supportsCaching: Bool = true

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        guard let projectID = provider.projectID, !projectID.isEmpty,
              let location = provider.location, !location.isEmpty else {
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
            contextWindowSize: provider.contextWindowSize,
            retryPolicy: resolveRetryPolicy(from: provider),
            reasoningConfig: reasoningConfig,
            cachingEnabled: provider.cachingEnabled
        )
    }
}

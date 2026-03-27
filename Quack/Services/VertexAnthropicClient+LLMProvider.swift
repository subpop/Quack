import Foundation
import AgentRunKit

extension VertexAnthropicClient: LLMProvider {
    static let platform: ProviderPlatform = .vertexAnthropic

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

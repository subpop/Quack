import Foundation
import AgentRunKit
import AgentRunKitFoundationModels

extension FoundationModelsClient: LLMProvider where C == EmptyContext {
    static var platform: ProviderPlatform { .foundationModels }

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
        // FoundationModelsClient manages tools internally via Apple's
        // LanguageModelSession. We pass an empty tool list here since tools
        // are provided at the Chat/Agent level, not at client construction.
        return FoundationModelsClient<EmptyContext>(
            tools: [] as [any AnyTool<EmptyContext>],
            context: EmptyContext()
        )
    }
}

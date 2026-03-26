import Foundation
import AgentRunKit
import AgentRunKitFoundationModels

extension FoundationModelsClient: LLMProvider where C == EmptyContext {
    static var kind: ProviderKind { .foundationModels }

    static var requiresAPIKey: Bool { false }
    static var requiresBaseURL: Bool { false }

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
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

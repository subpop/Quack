import Foundation
import AgentRunKit
import AgentRunKitFoundationModels

/// Factory utilities for Apple Foundation Models (on-device inference).
///
/// Used by `ProviderPlatform.foundationModels` to construct clients.
/// No model listing is needed — the on-device model is the only option.
enum FoundationModelsClientFactory {

    static func makeClient() -> (any LLMClient)? {
        return FoundationModelsClient<EmptyContext>(
            tools: [] as [any AnyTool<EmptyContext>],
            context: EmptyContext()
        )
    }
}

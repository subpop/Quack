import Foundation
import SwiftData
import AgentRunKit

@Observable
@MainActor
final class ProviderService {
    private var clientCache: [String: any LLMClient] = [:]

    /// The UUID of the default provider, persisted in UserDefaults.
    var defaultProviderID: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: "defaultProviderID") else { return nil }
            return UUID(uuidString: str)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: "defaultProviderID")
        }
    }

    /// Resolve the effective Provider for a chat session, falling back to the global default.
    func resolvedProvider(for session: ChatSession, providers: [Provider]) -> Provider? {
        if let sessionProviderID = session.providerID,
           let provider = providers.first(where: { $0.id == sessionProviderID }) {
            return provider
        }
        return defaultProvider(from: providers)
    }

    /// Resolve the effective model identifier for a chat session.
    func resolvedModel(for session: ChatSession, providers: [Provider]) -> String {
        if let model = session.modelIdentifier { return model }
        return resolvedProvider(for: session, providers: providers)?.defaultModel ?? "unknown"
    }

    /// Get the default provider from the list.
    func defaultProvider(from providers: [Provider]) -> Provider? {
        if let id = defaultProviderID,
           let provider = providers.first(where: { $0.id == id }) {
            return provider
        }
        // Fallback: first enabled provider
        return providers.first(where: \.isEnabled) ?? providers.first
    }

    /// Build an `LLMClient` for the given session.
    ///
    /// Delegates construction to the `LLMProvider` implementation registered
    /// for the provider's kind. Each `LLMProvider` encapsulates its own
    /// authentication, URL validation, and client construction logic.
    func makeClient(
        for session: ChatSession,
        providers: [Provider]
    ) -> (any LLMClient)? {
        guard let provider = resolvedProvider(for: session, providers: providers),
              provider.isEnabled else {
            return nil
        }

        let model = session.modelIdentifier ?? provider.defaultModel
        let maxTokens = session.maxTokens ?? provider.maxTokens
        let reasoningConfig = Self.resolveReasoningConfig(
            sessionEffort: session.reasoningEffort,
            providerEffort: provider.reasoningEffort
        )

        return provider.kind.providerType.makeClient(
            from: provider,
            model: model,
            maxTokens: maxTokens,
            reasoningConfig: reasoningConfig
        )
    }

    func invalidateCache() {
        clientCache.removeAll()
    }

    // MARK: - Private

    private static func resolveReasoningConfig(sessionEffort: String?, providerEffort: String?) -> ReasoningConfig? {
        guard let effortString = sessionEffort ?? providerEffort,
              let effort = ReasoningConfig.Effort(rawValue: effortString),
              effort != .none
        else { return nil }
        return ReasoningConfig(effort: effort)
    }
}

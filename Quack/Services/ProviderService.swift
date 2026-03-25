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

    /// Build an LLMClient for the given session.
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
        let contextWindowSize = provider.contextWindowSize

        let reasoningConfig = resolveReasoningConfig(
            sessionEffort: session.reasoningEffort,
            providerEffort: provider.reasoningEffort
        )

        let retryPolicy = RetryPolicy(
            maxAttempts: provider.retryMaxAttempts,
            baseDelay: .seconds(Int64(provider.retryBaseDelay)),
            maxDelay: .seconds(Int64(provider.retryMaxDelay))
        )

        switch provider.kind {
        case .openAICompatible:
            let apiKey: String
            if provider.requiresAPIKey {
                guard let key = KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id)) else {
                    return nil
                }
                apiKey = key
            } else {
                apiKey = "no-key-required"
            }
            guard let baseURLString = provider.baseURL,
                  let baseURL = URL(string: baseURLString) else {
                return nil
            }
            return OpenAIClient(
                apiKey: apiKey,
                model: model,
                maxTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                baseURL: baseURL,
                retryPolicy: retryPolicy,
                reasoningConfig: reasoningConfig
            )

        case .anthropic:
            guard let apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id)) else {
                return nil
            }
            let baseURL: URL? = if let urlStr = provider.baseURL { URL(string: urlStr) } else { nil }
            return AnthropicClient(
                apiKey: apiKey,
                model: model,
                maxTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                baseURL: baseURL ?? AnthropicClient.anthropicBaseURL,
                retryPolicy: retryPolicy,
                reasoningConfig: reasoningConfig,
                cachingEnabled: provider.cachingEnabled
            )

        case .foundationModels:
            return FoundationModelsLLMClient()

        case .gemini:
            guard let apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id)) else {
                return nil
            }
            guard let baseURLString = provider.baseURL,
                  let baseURL = URL(string: baseURLString) else {
                return nil
            }
            return GeminiClient(
                apiKey: apiKey,
                model: model,
                maxOutputTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                baseURL: baseURL,
                retryPolicy: retryPolicy
            )

        case .vertexGemini:
            let authProvider: GoogleAuthProvider
            do {
                authProvider = try GoogleAuthProvider()
            } catch {
                return nil
            }
            guard let baseURLString = provider.baseURL,
                  let baseURL = URL(string: baseURLString) else {
                return nil
            }
            return VertexGeminiClient(
                authProvider: authProvider,
                model: model,
                maxOutputTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                baseURL: baseURL,
                retryPolicy: retryPolicy
            )

        case .vertexAnthropic:
            // Vertex AI Anthropic: uses ADC for auth, no API key
            let authProvider: GoogleAuthProvider
            do {
                authProvider = try GoogleAuthProvider()
            } catch {
                return nil
            }

            guard let baseURLString = provider.baseURL,
                  let baseURL = URL(string: baseURLString) else {
                return nil
            }

            return VertexAnthropicClient(
                authProvider: authProvider,
                model: model,
                maxOutputTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                baseURL: baseURL,
                retryPolicy: retryPolicy
            )
        }
    }

    func invalidateCache() {
        clientCache.removeAll()
    }

    // MARK: - Private

    private func resolveReasoningConfig(sessionEffort: String?, providerEffort: String?) -> ReasoningConfig? {
        guard let effortString = sessionEffort ?? providerEffort,
              let effort = ReasoningConfig.Effort(rawValue: effortString),
              effort != .none
        else { return nil }
        return ReasoningConfig(effort: effort)
    }
}

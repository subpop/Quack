import Foundation
import AgentRunKit

/// The bridge between a persisted `Provider` configuration and a concrete `LLMClient`.
///
/// Each provider kind (OpenAI-compatible, Anthropic, Gemini, etc.) conforms to this
/// protocol via a static extension on the corresponding `LLMClient` type. This moves
/// the construction logic out of a central switch in `ProviderService` and into
/// the provider implementations themselves.
///
/// To add a new provider:
/// 1. Add a case to `ProviderKind`
/// 2. Write the `LLMClient` implementation
/// 3. Conform it to `LLMProvider`
/// 4. Map the new `ProviderKind` case to the conforming type in `ProviderKind.providerType`
protocol LLMProvider: Sendable {
    /// The `ProviderKind` this implementation handles.
    static var kind: ProviderKind { get }

    /// Whether this provider kind requires an API key by default.
    static var requiresAPIKey: Bool { get }

    /// Whether this provider kind requires a base URL.
    static var requiresBaseURL: Bool { get }

    /// The default base URL for newly created providers of this kind, if any.
    static var defaultBaseURL: String? { get }

    /// Whether this provider kind supports Anthropic-style prompt caching.
    static var supportsCaching: Bool { get }

    /// Construct an `LLMClient` from the given `Provider` configuration.
    ///
    /// Returns `nil` if required configuration is missing (e.g. no API key, invalid URL).
    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)?

    /// Query the provider's API for available model identifiers.
    ///
    /// Returns an array of model ID strings sorted alphabetically.
    /// Throws if the network request fails or the response is unparseable.
    /// The default implementation returns an empty array, signaling that
    /// the caller should fall back to `ProviderKind.knownModels`.
    static func listModels(for provider: Provider) async throws -> [String]
}

// MARK: - Defaults

extension LLMProvider {
    static var defaultBaseURL: String? { nil }
    static var supportsCaching: Bool { false }
    static func listModels(for provider: Provider) async throws -> [String] { [] }
}

// MARK: - Shared Helpers

extension LLMProvider {
    /// Build a `RetryPolicy` from the provider's stored retry settings.
    static func resolveRetryPolicy(from provider: Provider) -> RetryPolicy {
        RetryPolicy(
            maxAttempts: provider.retryMaxAttempts,
            baseDelay: .seconds(Int64(provider.retryBaseDelay)),
            maxDelay: .seconds(Int64(provider.retryMaxDelay))
        )
    }

    /// Load the API key from the keychain for the given provider.
    /// Returns `nil` if no key is stored.
    static func resolveAPIKey(for provider: Provider) -> String? {
        KeychainService.load(key: KeychainService.apiKeyKey(for: provider.id))
    }

    /// Parse and validate the provider's base URL.
    static func resolveBaseURL(from provider: Provider) -> URL? {
        guard let urlString = provider.baseURL,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
}

import Foundation
import AgentRunKit

/// The bridge between a `ProviderProfile` configuration and a concrete `LLMClient`.
///
/// Each provider platform (OpenAI-compatible, Anthropic, Gemini, etc.) conforms to this
/// protocol via a static extension on the corresponding `LLMClient` type. The protocol
/// is decoupled from SwiftData — `makeClient` and `listModels` accept individual
/// parameters rather than the `@Model` object directly.
///
/// To add a new provider:
/// 1. Add a case to `ProviderPlatform`
/// 2. Write the `LLMClient` implementation
/// 3. Conform it to `LLMProvider`
/// 4. Map the new `ProviderPlatform` case to the conforming type in `ProviderPlatform.providerType`
protocol LLMProvider: Sendable {
    /// The `ProviderPlatform` this implementation handles.
    static var platform: ProviderPlatform { get }

    /// Construct an `LLMClient` from the given parameters.
    ///
    /// Returns `nil` if required configuration is missing (e.g. no API key, invalid URL).
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
    ) -> (any LLMClient)?

    /// Query the provider's API for available model identifiers.
    ///
    /// Returns an array of model ID strings sorted alphabetically.
    /// Throws if the network request fails or the response is unparseable.
    /// The default implementation returns an empty array, signaling that
    /// the caller should fall back to `ProviderPlatform.knownModels`.
    static func listModels(
        baseURL: URL?,
        apiKey: String?,
        projectID: String?,
        location: String?
    ) async throws -> [String]
}

// MARK: - Defaults

extension LLMProvider {
    static func listModels(
        baseURL: URL?,
        apiKey: String?,
        projectID: String?,
        location: String?
    ) async throws -> [String] { [] }
}

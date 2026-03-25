import Foundation

/// The API wire protocol used to communicate with a provider's backend.
/// This enum is intentionally small -- it represents the shape of the HTTP API,
/// not the identity of the provider. Multiple providers can share the same kind
/// (e.g., OpenAI, OpenRouter, Groq, Together, and Ollama are all `.openAICompatible`).
enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// OpenAI Chat Completions API (also used by OpenRouter, Groq, Together, Ollama, etc.)
    case openAICompatible = "openai_compatible"

    /// Anthropic Messages API (Claude)
    case anthropic = "anthropic"

    /// Apple Foundation Models (on-device via FoundationModels framework)
    case foundationModels = "foundation_models"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: "OpenAI Compatible"
        case .anthropic: "Anthropic"
        case .foundationModels: "Apple Intelligence"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openAICompatible, .anthropic: true
        case .foundationModels: false
        }
    }

    var requiresBaseURL: Bool {
        switch self {
        case .openAICompatible, .anthropic: true
        case .foundationModels: false
        }
    }

    /// Whether this kind supports the Anthropic-specific prompt caching feature.
    var supportsCaching: Bool {
        self == .anthropic
    }
}

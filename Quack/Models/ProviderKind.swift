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

    /// Google Gemini API (AI Studio)
    case gemini = "gemini"

    /// Gemini models on Google Cloud Vertex AI
    case vertexGemini = "vertex_gemini"

    /// Anthropic Claude models on Google Cloud Vertex AI
    case vertexAnthropic = "vertex_anthropic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: "OpenAI Compatible"
        case .anthropic: "Anthropic"
        case .foundationModels: "Apple Intelligence"
        case .gemini: "Gemini"
        case .vertexGemini: "Vertex AI (Gemini)"
        case .vertexAnthropic: "Vertex AI (Claude)"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openAICompatible, .anthropic, .gemini: true
        case .foundationModels, .vertexGemini, .vertexAnthropic: false
        }
    }

    var requiresBaseURL: Bool {
        switch self {
        case .openAICompatible, .anthropic, .gemini, .vertexGemini, .vertexAnthropic: true
        case .foundationModels: false
        }
    }

    /// The default base URL for newly created providers of this kind.
    var defaultBaseURL: String? {
        switch self {
        case .anthropic: "https://api.anthropic.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/models"
        case .vertexGemini: "https://us-central1-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/us-central1"
        case .vertexAnthropic: "https://us-east5-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/us-east5"
        case .openAICompatible, .foundationModels: nil
        }
    }

    /// Whether this kind supports the Anthropic-specific prompt caching feature.
    var supportsCaching: Bool {
        self == .anthropic
    }
}

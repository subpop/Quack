import Foundation
import SwiftUI
import AgentRunKit

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

    var icon: Image {
        switch self {
        case .foundationModels: Image(systemName: "apple.intelligence")
        case .openAICompatible: Image("openai")
        case .gemini: Image("gemini")
        case .anthropic: Image("anthropic")
        default: Image(systemName: "cloud")
        }
    }

    /// Whether the icon is a custom asset (as opposed to an SF Symbol).
    /// Custom assets need explicit sizing via `.resizable()` to match SF Symbol scale.
    var isCustomIcon: Bool {
        switch self {
        case .openAICompatible, .gemini, .anthropic: true
        default: false
        }
    }

    /// The `LLMProvider` conforming type that handles this provider kind.
    var providerType: any LLMProvider.Type {
        switch self {
        case .openAICompatible: OpenAIClient.self
        case .anthropic: AnthropicClient.self
        case .foundationModels: FoundationModelsLLMClient.self
        case .gemini: GeminiClient.self
        case .vertexGemini: VertexGeminiClient.self
        case .vertexAnthropic: VertexAnthropicClient.self
        }
    }
}

import Foundation
import SwiftUI
import AgentRunKit
import AgentRunKitFoundationModels

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
        case .foundationModels: FoundationModelsClient<EmptyContext>.self
        case .gemini: GeminiClient.self
        case .vertexGemini: VertexGoogleClient.self
        case .vertexAnthropic: VertexAnthropicClient.self
        }
    }

    /// Hardcoded fallback model list used when the provider API is unavailable
    /// or does not support model listing.
    var knownModels: [String] {
        switch self {
        case .openAICompatible:
            ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "o3", "o4-mini"]
        case .anthropic:
            ["claude-sonnet-4-20250514", "claude-opus-4-20250514", "claude-haiku-3-5-20241022"]
        case .foundationModels:
            []
        case .gemini:
            ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
        case .vertexGemini:
            ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
        case .vertexAnthropic:
            ["claude-opus-4-6", "claude-sonnet-4-6", "claude-sonnet-4-5@20250929", "claude-haiku-4-5@20251001"]
        }
    }
}

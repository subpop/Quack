import Foundation
import SwiftData

/// A configured LLM provider. Users can add, remove, and duplicate these freely.
/// Multiple providers can share the same `ProviderKind` (e.g., several OpenAI-compatible
/// endpoints like OpenAI, OpenRouter, Groq, Together, or a custom proxy).
@Model
final class Provider {
    // MARK: - Identity

    var id: UUID
    var name: String
    var kindRaw: String
    var isEnabled: Bool
    var sortOrder: Int

    // MARK: - Connection

    var baseURL: String?
    var requiresAPIKey: Bool

    // MARK: - Model Defaults

    var defaultModel: String

    // MARK: - Parameters

    var maxTokens: Int
    var contextWindowSize: Int?
    var reasoningEffort: String?

    // MARK: - Provider-Specific

    var cachingEnabled: Bool  // Anthropic prompt caching

    // MARK: - Retry Policy

    var retryMaxAttempts: Int
    var retryBaseDelay: Double
    var retryMaxDelay: Double

    // MARK: - Computed Properties

    var kind: ProviderKind {
        get { ProviderKind(rawValue: kindRaw) ?? .openAICompatible }
        set { kindRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        name: String,
        kind: ProviderKind,
        isEnabled: Bool = false,
        sortOrder: Int = 0,
        baseURL: String? = nil,
        requiresAPIKey: Bool = true,
        defaultModel: String = "",
        maxTokens: Int = 4096,
        contextWindowSize: Int? = nil,
        cachingEnabled: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.defaultModel = defaultModel
        self.maxTokens = maxTokens
        self.contextWindowSize = contextWindowSize
        self.cachingEnabled = cachingEnabled
        self.retryMaxAttempts = 3
        self.retryBaseDelay = 1.0
        self.retryMaxDelay = 30.0
    }

    // MARK: - Factory: Built-in Providers

    /// Create the set of default providers seeded on first launch.
    static func builtInProviders() -> [Provider] {
        [
            Provider(
                name: "Apple Intelligence",
                kind: .foundationModels,
                isEnabled: true,
                sortOrder: 3,
                requiresAPIKey: false,
                defaultModel: "on-device",
                maxTokens: 4096,
                contextWindowSize: 4096
            ),
        ]
    }

    /// Create a set of providers for use in previews.
    static func previewProviders() -> [Provider] {
        [
            Provider(
                name: "OpenAI",
                kind: .openAICompatible,
                sortOrder: 0,
                baseURL: "https://api.openai.com/v1",
                requiresAPIKey: true,
                defaultModel: "gpt-4o",
                maxTokens: 16384,
                contextWindowSize: 128_000
            ),
            Provider(
                name: "Anthropic",
                kind: .anthropic,
                sortOrder: 1,
                baseURL: "https://api.anthropic.com/v1",
                requiresAPIKey: true,
                defaultModel: "claude-sonnet-4-20250514",
                maxTokens: 8192,
                contextWindowSize: 200_000
            ),
            Provider(
                name: "Ollama",
                kind: .openAICompatible,
                sortOrder: 2,
                baseURL: "http://localhost:11434/v1",
                requiresAPIKey: false,
                defaultModel: "llama3.2",
                maxTokens: 4096
            ),
            Provider(
                name: "Apple Intelligence",
                kind: .foundationModels,
                isEnabled: true,
                sortOrder: 3,
                requiresAPIKey: false,
                defaultModel: "on-device",
                maxTokens: 4096,
                contextWindowSize: 4096
            ),
            Provider(
                name: "Google AI",
                kind: .gemini,
                sortOrder: 4,
                baseURL: "https://generativelanguage.googleapis.com/v1beta/models",
                requiresAPIKey: true,
                defaultModel: "gemini-2.5-flash",
                maxTokens: 8192,
                contextWindowSize: 1_048_576
            ),
            Provider(
                name: "Vertex AI (Gemini)",
                kind: .vertexGemini,
                sortOrder: 5,
                baseURL: "https://us-central1-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/us-central1",
                requiresAPIKey: false,
                defaultModel: "gemini-2.5-flash",
                maxTokens: 8192,
                contextWindowSize: 1_048_576
            ),
            Provider(
                name: "Vertex AI (Claude)",
                kind: .vertexAnthropic,
                sortOrder: 6,
                baseURL: "https://us-east5-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/us-east5",
                requiresAPIKey: false,
                defaultModel: "claude-sonnet-4-6",
                maxTokens: 8192,
                contextWindowSize: 200_000
            ),
        ]
    }
}

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
    var suggestedModelsRaw: String  // newline-separated

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

    var suggestedModels: [String] {
        get {
            guard !suggestedModelsRaw.isEmpty else { return [] }
            return suggestedModelsRaw.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        set {
            suggestedModelsRaw = newValue.joined(separator: "\n")
        }
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
        suggestedModels: [String] = [],
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
        self.suggestedModelsRaw = suggestedModels.joined(separator: "\n")
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
                name: "OpenAI",
                kind: .openAICompatible,
                sortOrder: 0,
                baseURL: "https://api.openai.com/v1",
                requiresAPIKey: true,
                defaultModel: "gpt-4o",
                suggestedModels: ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "o3", "o4-mini"],
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
                suggestedModels: ["claude-sonnet-4-20250514", "claude-opus-4-20250514", "claude-haiku-3-5-20241022"],
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
                suggestedModels: ["llama3.2", "llama3.1", "qwen3", "mistral", "gemma3", "phi4", "deepseek-r1"],
                maxTokens: 4096
            ),
            Provider(
                name: "Apple Intelligence",
                kind: .foundationModels,
                isEnabled: true,
                sortOrder: 3,
                requiresAPIKey: false,
                defaultModel: "on-device",
                suggestedModels: ["on-device"],
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
                suggestedModels: ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"],
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
                suggestedModels: ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"],
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
                suggestedModels: ["claude-opus-4-6", "claude-sonnet-4-6", "claude-sonnet-4-5@20250929", "claude-haiku-4-5@20251001"],
                maxTokens: 8192,
                contextWindowSize: 200_000
            ),
        ]
    }
}

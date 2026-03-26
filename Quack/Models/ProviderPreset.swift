import Foundation
import SwiftUI

/// Pre-configured templates for common LLM providers.
///
/// Each preset bundles the `ProviderKind`, base URL, API-key requirement,
/// and a sensible default model so users can add popular providers in one
/// click instead of filling in fields manually. The `.custom` case
/// bypasses the preset flow and opens a blank provider for manual editing.
enum ProviderPreset: String, CaseIterable, Identifiable, Sendable {
    case ollama
    case openAI
    case anthropic
    case gemini
    case openRouter
    case groq
    case together
    case mistral
    case custom

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .ollama:     "Ollama"
        case .openAI:     "OpenAI"
        case .anthropic:  "Anthropic"
        case .gemini:     "Google Gemini"
        case .openRouter: "OpenRouter"
        case .groq:       "Groq"
        case .together:   "Together"
        case .mistral:    "Mistral"
        case .custom:     "Custom"
        }
    }

    var icon: Image {
        switch self {
        case .ollama:     Image("ollama")
        case .openAI:     Image("openai")
        case .anthropic:  Image("anthropic")
        case .gemini:     Image("gemini")
        case .openRouter: Image("openrouter")
        case .groq:       Image("groq")
        case .together:   Image("together")
        case .mistral:    Image("mistral")
        case .custom:     Image(systemName: "slider.horizontal.3")
        }
    }

    /// Whether the icon is a custom asset (as opposed to an SF Symbol).
    /// Custom assets need explicit sizing via `.resizable()` to match SF Symbol scale.
    var isCustomIcon: Bool {
        switch self {
        case .custom: false
        default: true
        }
    }

    // MARK: - Configuration

    var kind: ProviderKind {
        switch self {
        case .ollama:     .openAICompatible
        case .openAI:     .openAICompatible
        case .anthropic:  .anthropic
        case .gemini:     .gemini
        case .openRouter: .openAICompatible
        case .groq:       .openAICompatible
        case .together:   .openAICompatible
        case .mistral:    .openAICompatible
        case .custom:     .openAICompatible
        }
    }

    var baseURL: String? {
        switch self {
        case .ollama:     "http://localhost:11434/v1"
        case .openAI:     "https://api.openai.com/v1"
        case .anthropic:  "https://api.anthropic.com/v1"
        case .gemini:     "https://generativelanguage.googleapis.com/v1beta/models"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .groq:       "https://api.groq.com/openai/v1"
        case .together:   "https://api.together.xyz/v1"
        case .mistral:    "https://api.mistral.ai/v1"
        case .custom:     nil
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama: false
        default:      true
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama:     "llama3.2"
        case .openAI:     "gpt-4o"
        case .anthropic:  "claude-sonnet-4-20250514"
        case .gemini:     "gemini-2.5-flash"
        case .openRouter: ""
        case .groq:       "llama-3.3-70b-versatile"
        case .together:   "meta-llama/Llama-3.3-70B-Instruct-Turbo"
        case .mistral:    "mistral-large-latest"
        case .custom:     ""
        }
    }
}

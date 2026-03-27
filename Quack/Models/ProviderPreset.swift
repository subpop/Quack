// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftUI

/// Pre-configured templates for common LLM providers.
///
/// Each preset bundles a `ProviderPlatform`, connection details, and sensible
/// defaults for all profile fields so users can add popular providers in one
/// click. When a preset is selected, its values are *copied* into a new
/// `ProviderProfile`, which the user can then edit independently.
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

    // MARK: - Connection

    var platform: ProviderPlatform {
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
        case .gemini:     nil
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

    // MARK: - Model Defaults

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

    var maxTokens: Int {
        switch self {
        case .anthropic:  40_000
        case .openAI:     16_384
        case .gemini:     40_000
        case .groq:       8_192
        case .together:   8_192
        case .mistral:    8_192
        case .openRouter: 16_384
        case .ollama:     4_096
        case .custom:     4_096
        }
    }

    var contextWindowSize: Int? {
        switch self {
        case .openAI:     128_000
        case .anthropic:  200_000
        case .gemini:     1_048_576
        case .groq:       128_000
        case .openRouter: nil
        case .together:   128_000
        case .mistral:    128_000
        default:          nil
        }
    }

    var reasoningEffort: String? { nil }

    // MARK: - Provider-Specific

    var cachingEnabled: Bool {
        switch self {
        case .anthropic: true
        default: false
        }
    }

    var retryMaxAttempts: Int { 3 }
    var retryBaseDelay: Double { 1.0 }
    var retryMaxDelay: Double { 30.0 }

    // MARK: - Factory

    /// Create a new `ProviderProfile` by copying all preset values.
    func makeProfile(sortOrder: Int) -> ProviderProfile {
        ProviderProfile(
            name: self == .custom ? "New Provider" : displayName,
            platform: platform,
            sortOrder: sortOrder,
            baseURL: baseURL,
            requiresAPIKey: requiresAPIKey,
            defaultModel: defaultModel,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            reasoningEffort: reasoningEffort,
            cachingEnabled: cachingEnabled,
            retryMaxAttempts: retryMaxAttempts,
            retryBaseDelay: retryBaseDelay,
            retryMaxDelay: retryMaxDelay
        )
    }
}

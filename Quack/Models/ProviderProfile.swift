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
import SwiftData

/// A user-configured LLM provider profile. Users can add, remove, and duplicate these freely.
///
/// Profiles are typically created from a `ProviderPreset`, which copies all default values
/// into the profile. From that point on, the profile is independently editable by the user.
/// Multiple profiles can share the same `ProviderPlatform` (e.g., several OpenAI-compatible
/// endpoints like OpenAI, OpenRouter, Groq, Together, or a custom proxy).
@Model
final class ProviderProfile {
    // MARK: - Identity

    var id: UUID
    var name: String
    var kindRaw: String
    var isEnabled: Bool
    var sortOrder: Int

    // MARK: - Connection

    var baseURL: String?
    var requiresAPIKey: Bool

    // MARK: - Vertex AI

    var projectID: String?
    var location: String?

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

    var platform: ProviderPlatform {
        get { ProviderPlatform(rawValue: kindRaw) ?? .openAICompatible }
        set { kindRaw = newValue.rawValue }
    }

    // MARK: - Init

    init(
        name: String,
        platform: ProviderPlatform,
        isEnabled: Bool = false,
        sortOrder: Int = 0,
        baseURL: String? = nil,
        requiresAPIKey: Bool = true,
        defaultModel: String = "",
        maxTokens: Int = 4096,
        contextWindowSize: Int? = nil,
        reasoningEffort: String? = nil,
        cachingEnabled: Bool = false,
        retryMaxAttempts: Int = 3,
        retryBaseDelay: Double = 1.0,
        retryMaxDelay: Double = 30.0,
        projectID: String? = nil,
        location: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = platform.rawValue
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.defaultModel = defaultModel
        self.maxTokens = maxTokens
        self.contextWindowSize = contextWindowSize
        self.reasoningEffort = reasoningEffort
        self.cachingEnabled = cachingEnabled
        self.retryMaxAttempts = retryMaxAttempts
        self.retryBaseDelay = retryBaseDelay
        self.retryMaxDelay = retryMaxDelay
        self.projectID = projectID
        self.location = location
    }

    // MARK: - Factory: Built-in Profiles

    /// Create the set of default profiles seeded on first launch.
    static func builtInProfiles() -> [ProviderProfile] {
        [
            ProviderProfile(
                name: "Apple Intelligence",
                platform: .foundationModels,
                isEnabled: true,
                sortOrder: 3,
                requiresAPIKey: false,
                defaultModel: "on-device",
                maxTokens: 4096,
                contextWindowSize: 4096
            ),
        ]
    }

    /// Create a set of profiles for use in previews.
    static func previewProfiles() -> [ProviderProfile] {
        [
            ProviderProfile(
                name: "OpenAI",
                platform: .openAICompatible,
                sortOrder: 0,
                baseURL: "https://api.openai.com/v1",
                requiresAPIKey: true,
                defaultModel: "gpt-4o",
                maxTokens: 16384,
                contextWindowSize: 128_000
            ),
            ProviderProfile(
                name: "Anthropic",
                platform: .anthropic,
                sortOrder: 1,
                baseURL: "https://api.anthropic.com/v1",
                requiresAPIKey: true,
                defaultModel: "claude-sonnet-4-20250514",
                maxTokens: 40_000,
                contextWindowSize: 200_000
            ),
            ProviderProfile(
                name: "Ollama",
                platform: .openAICompatible,
                sortOrder: 2,
                baseURL: "http://localhost:11434/v1",
                requiresAPIKey: false,
                defaultModel: "llama3.2",
                maxTokens: 4096
            ),
            ProviderProfile(
                name: "Apple Intelligence",
                platform: .foundationModels,
                isEnabled: true,
                sortOrder: 3,
                requiresAPIKey: false,
                defaultModel: "on-device",
                maxTokens: 4096,
                contextWindowSize: 4096
            ),
            ProviderProfile(
                name: "Google AI",
                platform: .gemini,
                sortOrder: 4,
                requiresAPIKey: true,
                defaultModel: "gemini-2.5-flash",
                maxTokens: 40_000,
                contextWindowSize: 1_048_576
            ),
            ProviderProfile(
                name: "Vertex AI (Gemini)",
                platform: .vertexGemini,
                sortOrder: 5,
                requiresAPIKey: false,
                defaultModel: "gemini-2.5-flash",
                maxTokens: 40_000,
                contextWindowSize: 1_048_576,
                projectID: "my-project",
                location: "us-central1"
            ),
            ProviderProfile(
                name: "Vertex AI (Claude)",
                platform: .vertexAnthropic,
                sortOrder: 6,
                requiresAPIKey: false,
                defaultModel: "claude-sonnet-4-6",
                maxTokens: 40_000,
                contextWindowSize: 200_000,
                projectID: "my-project",
                location: "us-east5"
            ),
        ]
    }
}

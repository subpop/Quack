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
import SwiftUI

/// A user-configured LLM provider profile. Users can add, remove, and duplicate these freely.
///
/// Profiles are typically created from a `ProviderPreset`, which copies all default values
/// into the profile. From that point on, the profile is independently editable by the user.
/// Multiple profiles can share the same `ProviderPlatform` (e.g., several OpenAI-compatible
/// endpoints like OpenAI, OpenRouter, Groq, Together, or a custom proxy).
@Model
public final class ProviderProfile {
    // MARK: - Identity

    public var id: UUID
    public var name: String
    public var kindRaw: String
    public var isEnabled: Bool
    public var sortOrder: Int

    // MARK: - Icon

    /// The asset or SF Symbol name used to display this profile's icon.
    /// Set from the originating preset; updated when the platform changes.
    public var iconName: String
    /// Whether `iconName` refers to a custom image asset (true) or an SF Symbol (false).
    public var iconIsCustom: Bool
    /// The color name used for the icon badge background.
    public var iconColorName: String

    // MARK: - Connection

    public var baseURL: String?
    public var requiresAPIKey: Bool

    // MARK: - Vertex AI

    public var projectID: String?
    public var location: String?

    // MARK: - Model Defaults

    public var defaultModel: String

    // MARK: - Parameters

    public var maxTokens: Int
    public var contextWindowSize: Int?
    public var reasoningEffort: String?

    // MARK: - Provider-Specific

    public var cachingEnabled: Bool  // Anthropic prompt caching

    // MARK: - Retry Policy

    public var retryMaxAttempts: Int
    public var retryBaseDelay: Double
    public var retryMaxDelay: Double

    // MARK: - Pricing

    /// The models.dev provider ID used for pricing lookups.
    /// Set from the originating `ProviderPreset` at creation time.
    /// `nil` means no cost estimation is available (e.g. Ollama, custom endpoints).
    public var modelsDevProviderID: String?

    // MARK: - Computed Properties

    public var platform: ProviderPlatform {
        get { ProviderPlatform(rawValue: kindRaw) ?? .openAICompatible }
        set {
            kindRaw = newValue.rawValue
            // Keep the icon in sync with the platform when it changes.
            applyDefaultIcon(for: newValue)
        }
    }

    /// Update the stored icon fields to match the given platform's defaults.
    private func applyDefaultIcon(for platform: ProviderPlatform) {
        switch platform {
        case .openAICompatible:
            iconName = "openai"; iconIsCustom = true; iconColorName = "green"
        case .anthropic:
            iconName = "anthropic"; iconIsCustom = true; iconColorName = "orange"
        case .foundationModels:
            iconName = "apple.intelligence"; iconIsCustom = false; iconColorName = "blue"
        case .gemini:
            iconName = "gemini"; iconIsCustom = true; iconColorName = "blue"
        case .vertexGemini:
            iconName = "cloud"; iconIsCustom = false; iconColorName = "indigo"
        case .vertexAnthropic:
            iconName = "cloud"; iconIsCustom = false; iconColorName = "purple"
        case .mlx:
            iconName = "cpu"; iconIsCustom = false; iconColorName = "teal"
        }
    }

    /// The image to display for this profile, derived from the stored icon name.
    public var icon: Image {
        if iconIsCustom {
            Image(iconName)
        } else {
            Image(systemName: iconName)
        }
    }

    /// The color to use for the icon badge background.
    public var iconColor: Color {
        switch iconColorName {
        case "gray": .gray
        case "green": .green
        case "orange": .orange
        case "blue": .blue
        case "purple": .purple
        case "indigo": .indigo
        case "cyan": .cyan
        case "secondary": .secondary
        default: .green
        }
    }

    // MARK: - Init

    public init(
        name: String,
        platform: ProviderPlatform,
        isEnabled: Bool = true,
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
        location: String? = nil,
        iconName: String? = nil,
        iconIsCustom: Bool? = nil,
        iconColorName: String? = nil,
        modelsDevProviderID: String? = nil
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
        self.modelsDevProviderID = modelsDevProviderID
        // Use provided icon values, or derive defaults from the platform.
        if let iconName, let iconIsCustom, let iconColorName {
            self.iconName = iconName
            self.iconIsCustom = iconIsCustom
            self.iconColorName = iconColorName
        } else {
            // Set temporary values, then apply platform defaults.
            self.iconName = ""
            self.iconIsCustom = false
            self.iconColorName = ""
            applyDefaultIcon(for: platform)
        }
    }

    // MARK: - Factory: Built-in Profiles

    /// Create the set of default profiles seeded on first launch.
    public static func builtInProfiles() -> [ProviderProfile] {
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
    public static func previewProfiles() -> [ProviderProfile] {
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
                maxTokens: 4096,
                iconName: "ollama",
                iconIsCustom: true,
                iconColorName: "gray"
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

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
import AgentRunKit
import AgentRunKitFoundationModels
import AgentRunKitMLX
import MLXLMCommon

/// The API wire protocol used to communicate with a provider's backend.
///
/// This enum represents the shape of the HTTP API and the connection details
/// necessary to talk to a particular class of provider. Multiple providers
/// can share the same platform (e.g., OpenAI, OpenRouter, Groq, Together,
/// and Ollama are all `.openAICompatible`).
enum ProviderPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
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

    /// MLX on-device inference via mlx-swift
    case mlx = "mlx"

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .openAICompatible: "OpenAI Compatible"
        case .anthropic: "Anthropic"
        case .foundationModels: "Apple Intelligence"
        case .gemini: "Gemini"
        case .vertexGemini: "Vertex AI (Gemini)"
        case .vertexAnthropic: "Vertex AI (Claude)"
        case .mlx: "MLX (On-Device)"
        }
    }

    var icon: Image {
        switch self {
        case .foundationModels: Image(systemName: "apple.intelligence")
        case .openAICompatible: Image("openai")
        case .gemini: Image("gemini")
        case .anthropic: Image("anthropic")
        case .mlx: Image(systemName: "cpu")
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


    // MARK: - Connection Capabilities

    /// Whether this platform requires an API key by default.
    var requiresAPIKey: Bool {
        switch self {
        case .openAICompatible, .anthropic, .gemini: true
        case .foundationModels, .vertexGemini, .vertexAnthropic, .mlx: false
        }
    }

    /// Whether this platform requires a base URL to be configured.
    var requiresBaseURL: Bool {
        switch self {
        case .openAICompatible, .anthropic: true
        case .foundationModels, .gemini, .vertexGemini, .vertexAnthropic, .mlx: false
        }
    }

    /// The default base URL for newly created providers of this platform, if any.
    var defaultBaseURL: String? {
        switch self {
        case .anthropic: "https://api.anthropic.com/v1"
        default: nil
        }
    }

    /// Whether this platform supports Anthropic-style prompt caching.
    var supportsCaching: Bool {
        switch self {
        case .anthropic, .vertexAnthropic: true
        default: false
        }
    }

    /// Default maxTokens for this platform, sized to accommodate output after reasoning.
    var defaultMaxTokens: Int {
        switch self {
        case .anthropic, .vertexAnthropic: 40_000
        case .gemini, .vertexGemini: 40_000
        case .openAICompatible: 16_384
        case .foundationModels: 4_096
        case .mlx: 4_096
        }
    }

    // MARK: - Client Construction

    /// Construct an `LLMClient` for this platform from the given parameters.
    ///
    /// Returns `nil` if required configuration is missing (e.g. no API key, invalid URL).
    /// Each case delegates to a platform-specific factory in a separate file to keep
    /// provider-specific logic isolated.
    ///
    /// - Parameter mlxContainer: A pre-loaded MLX `ModelContainer`. Required for `.mlx`,
    ///   ignored by all other platforms. Must be loaded via `MLXModelService` before calling.
    func makeClient(
        baseURL: URL?,
        apiKey: String?,
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool,
        projectID: String?,
        location: String?,
        mlxContainer: ModelContainer? = nil
    ) -> (any LLMClient)? {
        switch self {
        case .openAICompatible:
            return OpenAIClientFactory.makeClient(
                baseURL: baseURL, apiKey: apiKey, model: model,
                maxTokens: maxTokens, contextWindowSize: contextWindowSize,
                reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                cachingEnabled: cachingEnabled
            )
        case .anthropic:
            return AnthropicClientFactory.makeClient(
                baseURL: baseURL, apiKey: apiKey, model: model,
                maxTokens: maxTokens, contextWindowSize: contextWindowSize,
                reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                cachingEnabled: cachingEnabled
            )
        case .foundationModels:
            return FoundationModelsClientFactory.makeClient()
        case .gemini:
            return GeminiClientFactory.makeClient(
                apiKey: apiKey, model: model,
                maxTokens: maxTokens, contextWindowSize: contextWindowSize,
                reasoningConfig: reasoningConfig, retryPolicy: retryPolicy
            )
        case .vertexGemini:
            return VertexGoogleClientFactory.makeClient(
                model: model, maxTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                projectID: projectID, location: location
            )
        case .vertexAnthropic:
            return VertexAnthropicClientFactory.makeClient(
                model: model, maxTokens: maxTokens,
                contextWindowSize: contextWindowSize,
                reasoningConfig: reasoningConfig, retryPolicy: retryPolicy,
                cachingEnabled: cachingEnabled,
                projectID: projectID, location: location
            )
        case .mlx:
            return MLXClientFactory.makeClient(
                container: mlxContainer,
                model: model,
                maxTokens: maxTokens,
                contextWindowSize: contextWindowSize
            )
        }
    }

    /// Query the provider's API for available model identifiers.
    ///
    /// Returns an array of model ID strings sorted alphabetically.
    /// Returns an empty array if the platform doesn't support model listing,
    /// signaling that the caller should fall back to `knownModels`.
    func listModels(
        baseURL: URL?,
        apiKey: String?,
        projectID: String?,
        location: String?
    ) async throws -> [String] {
        switch self {
        case .openAICompatible:
            return try await OpenAIClientFactory.listModels(baseURL: baseURL, apiKey: apiKey)
        case .gemini:
            return try await GeminiClientFactory.listModels(apiKey: apiKey)
        case .vertexGemini:
            return try await VertexGoogleClientFactory.listModels(projectID: projectID, location: location)
        case .anthropic, .vertexAnthropic, .foundationModels:
            return []
        case .mlx:
            return MLXModelService.downloadedModelIDs()
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
        case .mlx:
            MLXModelService.downloadedModelIDs()
        }
    }
}

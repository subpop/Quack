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

/// The API wire protocol used to communicate with a provider's backend.
///
/// This enum represents the shape of the HTTP API and the connection details
/// necessary to talk to a particular class of provider. Multiple providers
/// can share the same platform (e.g., OpenAI, OpenRouter, Groq, Together,
/// and Ollama are all `.openAICompatible`).
public enum ProviderPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    // MARK: - Display

    public var displayName: String {
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

    public var icon: Image {
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
    public var isCustomIcon: Bool {
        switch self {
        case .openAICompatible, .gemini, .anthropic: true
        default: false
        }
    }


    // MARK: - Connection Capabilities

    /// Whether this platform requires an API key by default.
    public var requiresAPIKey: Bool {
        switch self {
        case .openAICompatible, .anthropic, .gemini: true
        case .foundationModels, .vertexGemini, .vertexAnthropic, .mlx: false
        }
    }

    /// Whether this platform requires a base URL to be configured.
    public var requiresBaseURL: Bool {
        switch self {
        case .openAICompatible, .anthropic: true
        case .foundationModels, .gemini, .vertexGemini, .vertexAnthropic, .mlx: false
        }
    }

    /// The default base URL for newly created providers of this platform, if any.
    public var defaultBaseURL: String? {
        switch self {
        case .anthropic: "https://api.anthropic.com/v1"
        default: nil
        }
    }

    /// Whether this platform supports Anthropic-style prompt caching.
    public var supportsCaching: Bool {
        switch self {
        case .anthropic, .vertexAnthropic: true
        default: false
        }
    }

    /// Default maxTokens for this platform, sized to accommodate output after reasoning.
    public var defaultMaxTokens: Int {
        switch self {
        case .anthropic, .vertexAnthropic: 40_000
        case .gemini, .vertexGemini: 40_000
        case .openAICompatible: 16_384
        case .foundationModels: 4_096
        case .mlx: 4_096
        }
    }

    // MARK: - Registered Client Factories

    /// Closure registered at app startup to construct an MLX `LLMClient`.
    ///
    /// By using a registered closure instead of a direct import, this file
    /// avoids importing `AgentRunKitMLX` / `MLXLMCommon`, keeping Metal-
    /// dependent code out of files that participate in Xcode Previews.
    ///
    /// Parameters: `(container: Any?, model: String?, maxTokens: Int, contextWindowSize: Int?) -> (any LLMClient)?`
    public nonisolated(unsafe) static var mlxClientFactory: ((Any?, String?, Int, Int?) -> (any LLMClient)?)?

    /// Closure registered at app startup to construct an `LLMClient` for a
    /// given platform.
    ///
    /// The main app target sets this at launch, wiring each platform case to
    /// its concrete factory (e.g. `OpenAIClientFactory`, `AnthropicClientFactory`).
    /// This keeps Metal / provider-specific imports out of the interface package.
    ///
    /// Parameters: `(platform, baseURL, apiKey, model, maxTokens, contextWindowSize, reasoningConfig, retryPolicy, cachingEnabled, projectID, location, mlxContainer) -> (any LLMClient)?`
    public nonisolated(unsafe) static var clientFactory: ((
        _ platform: ProviderPlatform,
        _ baseURL: URL?,
        _ apiKey: String?,
        _ model: String,
        _ maxTokens: Int,
        _ contextWindowSize: Int?,
        _ reasoningConfig: ReasoningConfig?,
        _ retryPolicy: RetryPolicy,
        _ cachingEnabled: Bool,
        _ projectID: String?,
        _ location: String?,
        _ mlxContainer: Any?
    ) -> (any LLMClient)?)?

    /// Closure registered at app startup to list models from a provider API.
    ///
    /// Parameters: `(platform, baseURL, apiKey, projectID, location) async throws -> [String]`
    public nonisolated(unsafe) static var modelListFactory: ((
        _ platform: ProviderPlatform,
        _ baseURL: URL?,
        _ apiKey: String?,
        _ projectID: String?,
        _ location: String?
    ) async throws -> [String])?

    // MARK: - Client Construction

    /// Construct an `LLMClient` for this platform from the given parameters.
    ///
    /// Returns `nil` if required configuration is missing (e.g. no API key, invalid URL).
    /// Delegates to the registered `clientFactory` closure, which the main app
    /// sets at startup to wire each platform to its concrete factory.
    ///
    /// - Parameter mlxContainer: A pre-loaded MLX model container (type-erased).
    ///   Required for `.mlx`, ignored by all other platforms. Must be loaded via
    ///   `MLXModelService` before calling.
    public func makeClient(
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
        mlxContainer: Any? = nil
    ) -> (any LLMClient)? {
        return Self.clientFactory?(
            self, baseURL, apiKey, model, maxTokens, contextWindowSize,
            reasoningConfig, retryPolicy, cachingEnabled, projectID, location,
            mlxContainer
        )
    }

    /// Query the provider's API for available model identifiers.
    ///
    /// Returns an array of model ID strings sorted alphabetically.
    /// Returns an empty array if the platform doesn't support model listing,
    /// signaling that the caller should fall back to `knownModels`.
    public func listModels(
        baseURL: URL?,
        apiKey: String?,
        projectID: String?,
        location: String?
    ) async throws -> [String] {
        guard let factory = Self.modelListFactory else {
            // Fall back to known models for platforms that don't list,
            // or when no factory is registered (e.g. previews).
            return []
        }
        return try await factory(self, baseURL, apiKey, projectID, location)
    }

    /// Hardcoded fallback model list used when the provider API is unavailable
    /// or does not support model listing.
    public var knownModels: [String] {
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
            mlxDownloadedModelIDsFromDisk()
        }
    }
}

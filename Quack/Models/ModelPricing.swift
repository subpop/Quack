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
import os

/// Per-token pricing for a model, expressed in USD per million tokens.
struct ModelPricing: Sendable {
    /// Cost in USD per 1M input tokens.
    let inputPerMTok: Double
    /// Cost in USD per 1M output tokens.
    let outputPerMTok: Double

    /// Calculate the estimated cost for a given number of input, output, and reasoning tokens.
    /// Reasoning tokens are charged at the output rate, matching industry convention.
    func cost(inputTokens: Int, outputTokens: Int, reasoningTokens: Int = 0) -> Double {
        let inputCost = Double(inputTokens) * inputPerMTok / 1_000_000
        let outputCost = Double(outputTokens) * outputPerMTok / 1_000_000
        let reasoningCost = Double(reasoningTokens) * outputPerMTok / 1_000_000
        return inputCost + outputCost + reasoningCost
    }
}

// MARK: - models.dev Service

/// Fetches and caches model pricing data from the models.dev API.
///
/// The models.dev registry (https://models.dev) is a community-maintained catalog of LLM models
/// and their pricing. This service fetches the full catalog, caches it in memory, and provides
/// a lookup function that maps a `(model, platform)` pair to a `ModelPricing`.
///
/// The cache refreshes automatically after `ttl` seconds, or can be refreshed manually.
@Observable
@MainActor
final class ModelPricingService {
    /// How long the cached data is considered fresh, in seconds.
    private static let ttl: TimeInterval = 5 * 60 // 5 minutes

    private static let apiURL = URL(string: "https://models.dev/api.json")!
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ModelPricingService")

    /// The raw decoded catalog, keyed by provider ID, then by model ID.
    private var catalog: [String: ModelsDevProvider] = [:]
    private var lastFetched: Date?
    private var fetchTask: Task<Void, Never>?

    /// Whether the catalog has been loaded at least once (even if expired).
    var isLoaded: Bool { lastFetched != nil }

    init() {
        // Fire off an initial fetch on creation.
        refresh()
    }

    /// Trigger a background refresh if the cache is stale or empty.
    func refresh() {
        guard fetchTask == nil else { return }
        if let lastFetched, Date().timeIntervalSince(lastFetched) < Self.ttl { return }

        fetchTask = Task {
            await fetchCatalog()
            fetchTask = nil
        }
    }

    /// Look up pricing for a model identifier.
    ///
    /// Uses a three-tier fallback strategy:
    /// 1. **Explicit provider ID** (`modelsDevProviderID` from the profile's preset) --
    ///    gives accurate per-provider pricing for OpenAI-compatible services like Groq or Together.
    /// 2. **Platform-based provider IDs** (`ProviderPlatform.modelsDevProviderIDs`) --
    ///    catches Vertex AI and other platform-specific mappings.
    /// 3. **nil** -- returned when no pricing data is available.
    ///
    /// For Apple Intelligence (on-device), returns zero cost without consulting the catalog.
    func price(
        for model: String,
        platform: ProviderPlatform,
        modelsDevProviderID: String? = nil
    ) -> ModelPricing? {
        if platform == .foundationModels {
            return ModelPricing(inputPerMTok: 0, outputPerMTok: 0)
        }

        // Build the ordered list of provider IDs to search.
        var providerIDs: [String] = []
        if let explicit = modelsDevProviderID {
            providerIDs.append(explicit)
        }
        for id in platform.modelsDevProviderIDs where !providerIDs.contains(id) {
            providerIDs.append(id)
        }

        for providerID in providerIDs {
            guard let provider = catalog[providerID] else { continue }

            // Try exact match first.
            if let modelData = provider.models[model], let cost = modelData.cost {
                return ModelPricing(inputPerMTok: cost.input, outputPerMTok: cost.output)
            }

            // Try case-insensitive match.
            let lowered = model.lowercased()
            for (key, modelData) in provider.models {
                if key.lowercased() == lowered, let cost = modelData.cost {
                    return ModelPricing(inputPerMTok: cost.input, outputPerMTok: cost.output)
                }
            }
        }

        return nil
    }

    // MARK: - Fetching

    private func fetchCatalog() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.apiURL)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                Self.logger.warning("models.dev returned non-200 status")
                return
            }

            let decoded = try JSONDecoder().decode([String: ModelsDevProvider].self, from: data)
            catalog = decoded
            lastFetched = Date()

            let modelCount = decoded.values.reduce(0) { $0 + $1.models.count }
            Self.logger.info("Loaded \(decoded.count) providers, \(modelCount) models from models.dev")
        } catch {
            Self.logger.error("Failed to fetch models.dev: \(error.localizedDescription)")
        }
    }
}

// MARK: - models.dev JSON Schema

/// A provider entry from the models.dev API.
private struct ModelsDevProvider: Decodable, Sendable {
    let id: String
    let name: String
    let models: [String: ModelsDevModel]
}

/// A model entry from the models.dev API.
/// Only the fields we need are decoded; the rest are ignored.
private struct ModelsDevModel: Decodable, Sendable {
    let id: String
    let name: String
    let cost: ModelsDevCost?
}

/// Cost information for a model, in USD per million tokens.
private struct ModelsDevCost: Decodable, Sendable {
    let input: Double
    let output: Double

    // Fields we decode but don't currently use — available for future enhancements.
    // let cache_read: Double?
    // let cache_write: Double?
}

// MARK: - ProviderPlatform → models.dev Mapping

extension ProviderPlatform {
    /// Platform-level fallback provider IDs for pricing lookups.
    ///
    /// These are only consulted when the profile's `modelsDevProviderID` is nil or
    /// doesn't yield a match. `openAICompatible` returns an empty array because the
    /// platform alone is ambiguous -- the specific provider (OpenAI, Groq, Together,
    /// Ollama, etc.) must come from `ProviderProfile.modelsDevProviderID`.
    var modelsDevProviderIDs: [String] {
        switch self {
        case .openAICompatible: []
        case .anthropic: ["anthropic"]
        case .gemini: ["google"]
        case .vertexGemini: ["google-vertex", "google"]
        case .vertexAnthropic: ["google-vertex-anthropic", "anthropic"]
        case .foundationModels: []
        }
    }
}

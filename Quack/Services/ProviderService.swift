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
import AgentRunKit

@Observable
@MainActor
final class ProviderService {
    private var clientCache: [String: any LLMClient] = [:]

    /// Resolve the effective ProviderProfile for a chat session, falling back to the first enabled profile.
    func resolvedProfile(for session: ChatSession, profiles: [ProviderProfile]) -> ProviderProfile? {
        if let sessionProviderID = session.providerID,
           let profile = profiles.first(where: { $0.id == sessionProviderID }) {
            return profile
        }
        return fallbackProfile(from: profiles)
    }

    /// Resolve the effective model identifier for a chat session.
    func resolvedModel(for session: ChatSession, profiles: [ProviderProfile]) -> String {
        if let model = session.modelIdentifier { return model }
        return resolvedProfile(for: session, profiles: profiles)?.defaultModel ?? "unknown"
    }

    /// Fallback profile when the session has no provider set.
    func fallbackProfile(from profiles: [ProviderProfile]) -> ProviderProfile? {
        profiles.first(where: \.isEnabled) ?? profiles.first
    }

    /// Build an `LLMClient` for the given session.
    ///
    /// Acts as a bridge: pulls configuration from the `ProviderProfile`, resolves
    /// API keys from the Keychain, and passes individual values to the platform's
    /// `makeClient()` method.
    func makeClient(
        for session: ChatSession,
        profiles: [ProviderProfile]
    ) -> (any LLMClient)? {
        guard let profile = resolvedProfile(for: session, profiles: profiles),
              profile.isEnabled else {
            return nil
        }

        let model = session.modelIdentifier ?? profile.defaultModel
        let providerMaxTokens = session.maxTokens ?? profile.maxTokens
        let baseMaxTokens = providerMaxTokens > 0 ? providerMaxTokens : profile.platform.defaultMaxTokens
        let reasoningConfig = Self.resolveReasoningConfig(
            sessionEffort: session.reasoningEffort,
            providerEffort: profile.reasoningEffort
        )
        let maxTokens = Self.adjustedMaxTokens(
            baseMaxTokens: baseMaxTokens,
            reasoningConfig: reasoningConfig
        )

        // Resolve connection details from profile
        let baseURL = Self.resolveBaseURL(from: profile)
        let apiKey: String?
        if profile.requiresAPIKey {
            apiKey = KeychainService.load(key: KeychainService.apiKeyKey(for: profile.id))
        } else {
            apiKey = "no-key-required"
        }
        let retryPolicy = Self.resolveRetryPolicy(from: profile)

        return profile.platform.makeClient(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: profile.contextWindowSize,
            reasoningConfig: reasoningConfig,
            retryPolicy: retryPolicy,
            cachingEnabled: profile.cachingEnabled,
            projectID: profile.projectID,
            location: profile.location
        )
    }

    func invalidateCache() {
        clientCache.removeAll()
    }

    // MARK: - Private

    /// Build a `RetryPolicy` from the profile's stored retry settings.
    private static func resolveRetryPolicy(from profile: ProviderProfile) -> RetryPolicy {
        RetryPolicy(
            maxAttempts: profile.retryMaxAttempts,
            baseDelay: .seconds(Int64(profile.retryBaseDelay)),
            maxDelay: .seconds(Int64(profile.retryMaxDelay))
        )
    }

    /// Parse and validate the profile's base URL.
    private static func resolveBaseURL(from profile: ProviderProfile) -> URL? {
        guard let urlString = profile.baseURL,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    /// Thinking budgets for Anthropic models by effort level.
    /// These must be less than maxTokens to satisfy Anthropic's constraint.
    private static let reasoningBudgets: [String: Int] = [
        "minimal": 1_024,
        "low": 4_096,
        "medium": 32_000,
        "high": 64_000,
        "xhigh": 100_000
    ]

    private static func resolveReasoningConfig(sessionEffort: String?, providerEffort: String?) -> ReasoningConfig? {
        guard let effortString = sessionEffort ?? providerEffort,
              let effort = ReasoningConfig.Effort(rawValue: effortString),
              effort != .none
        else { return nil }
        let budget = reasoningBudgets[effortString] ?? 32_000
        return ReasoningConfig(effort: effort, budgetTokens: budget)
    }

    private static func adjustedMaxTokens(baseMaxTokens: Int, reasoningConfig: ReasoningConfig?) -> Int {
        guard let config = reasoningConfig else { return baseMaxTokens }
        let budget = config.budgetTokens ?? 32_000
        let minOutputTokens = 8_192
        let required = budget + minOutputTokens
        return max(baseMaxTokens, required)
    }
}

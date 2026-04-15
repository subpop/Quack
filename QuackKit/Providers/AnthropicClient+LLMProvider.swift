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
import AgentRunKit
import QuackInterface

/// Factory utilities for Anthropic's Messages API.
///
/// Used by `ProviderPlatform.anthropic` to construct clients.
/// Anthropic does not expose a public model-listing endpoint, so
/// `ProviderPlatform.knownModels` is used as the fallback.
public enum AnthropicClientFactory {

    public static func makeClient(
        baseURL: URL?,
        apiKey: String?,
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool
    ) -> (any LLMClient)? {
        guard let apiKey else { return nil }

        let resolvedBaseURL = baseURL ?? AnthropicClient.anthropicBaseURL

        return AnthropicClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            baseURL: resolvedBaseURL,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig,
            cachingEnabled: cachingEnabled
        )
    }
}

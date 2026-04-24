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

/// Factory utilities for Anthropic Claude models on Google Cloud Vertex AI.
///
/// Used by `ProviderPlatform.vertexAnthropic` to construct clients.
/// Authenticates via Application Default Credentials through `GoogleAuthService`.
/// Anthropic does not expose a model-listing endpoint on Vertex, so
/// `ProviderPlatform.knownModels` is used as the fallback.
public enum VertexAnthropicClientFactory {

    public static func makeClient(
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        cachingEnabled: Bool,
        projectID: String?,
        location: String?
    ) -> (any LLMClient)? {
        guard let projectID, !projectID.isEmpty,
              let location, !location.isEmpty else {
            return nil
        }

        guard GoogleAuthService.credentialsAvailable() else { return nil }

        guard let authService = try? GoogleAuthService() else { return nil }

        return try? VertexAnthropicClient(
            projectID: projectID,
            location: location,
            model: model,
            authService: authService,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig,
            cachingEnabled: cachingEnabled
        )
    }
}

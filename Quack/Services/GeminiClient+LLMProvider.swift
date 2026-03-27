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

/// Factory and model-listing utilities for the Google Gemini API (AI Studio).
///
/// Used by `ProviderPlatform.gemini` to construct clients and fetch model lists.
enum GeminiClientFactory {

    static func makeClient(
        apiKey: String?,
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy
    ) -> (any LLMClient)? {
        guard let apiKey else { return nil }

        return GeminiClient(
            apiKey: apiKey,
            model: model,
            maxOutputTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig
        )
    }

    /// Queries the Gemini `GET /v1beta/models` endpoint for available models.
    static func listModels(apiKey: String?) async throws -> [String] {
        guard let apiKey else { return [] }

        let geminiBaseURL = GeminiClient.geminiBaseURL
        let modelsURL = geminiBaseURL.appendingPathComponent("v1beta/models")

        guard var components = URLComponents(url: modelsURL, resolvingAgainstBaseURL: false) else {
            return []
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let listURL = components.url else { return [] }

        var request = URLRequest(url: listURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        struct GeminiModelsResponse: Decodable {
            struct ModelInfo: Decodable {
                let name: String
            }
            let models: [ModelInfo]
        }

        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        return decoded.models
            .map { info in
                if info.name.hasPrefix("models/") {
                    return String(info.name.dropFirst(7))
                }
                return info.name
            }
            .sorted()
    }
}

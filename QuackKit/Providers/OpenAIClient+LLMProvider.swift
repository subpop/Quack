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

/// Factory and model-listing utilities for OpenAI-compatible providers.
///
/// Used by `ProviderPlatform.openAICompatible` to construct clients and fetch
/// model lists. Works with OpenAI, Ollama, OpenRouter, Groq, Together, and
/// any provider that implements the OpenAI Chat Completions API.
public enum OpenAIClientFactory {

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
        guard let baseURL else { return nil }

        return OpenAIClient(
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            baseURL: baseURL,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig
        )
    }

    /// Queries the OpenAI-compatible `GET /models` endpoint.
    public static func listModels(
        baseURL: URL?,
        apiKey: String?
    ) async throws -> [String] {
        guard let baseURL else { return [] }

        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"

        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        struct ModelsResponse: Decodable {
            struct Model: Decodable {
                let id: String
            }
            let data: [Model]
        }

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data.map(\.id).sorted()
    }
}

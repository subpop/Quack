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

/// Factory and model-listing utilities for Gemini models on Google Cloud Vertex AI.
///
/// Used by `ProviderPlatform.vertexGemini` to construct clients and fetch model lists.
/// Authenticates via Application Default Credentials through `GoogleAuthService`.
enum VertexGoogleClientFactory {

    static func makeClient(
        model: String,
        maxTokens: Int,
        contextWindowSize: Int?,
        reasoningConfig: ReasoningConfig?,
        retryPolicy: RetryPolicy,
        projectID: String?,
        location: String?
    ) -> (any LLMClient)? {
        guard let projectID, !projectID.isEmpty,
              let location, !location.isEmpty else {
            return nil
        }

        guard GoogleAuthService.credentialsAvailable() else { return nil }

        guard let authService = try? GoogleAuthService() else { return nil }

        return VertexGoogleClient(
            projectID: projectID,
            location: location,
            model: model,
            authService: authService,
            maxOutputTokens: maxTokens,
            contextWindowSize: contextWindowSize,
            retryPolicy: retryPolicy,
            reasoningConfig: reasoningConfig
        )
    }

    /// Queries the Vertex AI model listing endpoint.
    static func listModels(
        projectID: String?,
        location: String?
    ) async throws -> [String] {
        guard let projectID, !projectID.isEmpty,
              let location, !location.isEmpty else {
            return []
        }

        guard let authService = try? GoogleAuthService() else { return [] }

        let token = try await authService.accessToken()

        let urlString = "https://\(location)-aiplatform.googleapis.com"
            + "/v1/projects/\(projectID)/locations/\(location)/publishers/google/models"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        struct VertexModelsResponse: Decodable {
            struct ModelInfo: Decodable {
                let name: String
            }
            let models: [ModelInfo]?
            let publisherModels: [ModelInfo]?
        }

        let decoded = try JSONDecoder().decode(VertexModelsResponse.self, from: data)

        let models = decoded.publisherModels ?? decoded.models ?? []
        return models
            .compactMap { info -> String? in
                // Name format: publishers/google/models/{model-id}
                if let range = info.name.range(of: "models/") {
                    return String(info.name[range.upperBound...])
                }
                return info.name
            }
            .sorted()
    }
}

import Foundation
import AgentRunKit

extension VertexGoogleClient: LLMProvider {
    static let kind: ProviderKind = .vertexGemini

    static let requiresAPIKey: Bool = false
    static let requiresBaseURL: Bool = false

    static func makeClient(
        from provider: Provider,
        model: String,
        maxTokens: Int,
        reasoningConfig: ReasoningConfig?
    ) -> (any LLMClient)? {
        guard let projectID = provider.projectID, !projectID.isEmpty,
              let location = provider.location, !location.isEmpty else {
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
            contextWindowSize: provider.contextWindowSize,
            retryPolicy: resolveRetryPolicy(from: provider),
            reasoningConfig: reasoningConfig
        )
    }

    // MARK: - Model Listing

    /// Queries the Vertex AI model listing endpoint.
    static func listModels(for provider: Provider) async throws -> [String] {
        guard let projectID = provider.projectID, !projectID.isEmpty,
              let location = provider.location, !location.isEmpty else {
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

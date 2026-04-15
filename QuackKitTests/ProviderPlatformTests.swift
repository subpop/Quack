import Testing
import Foundation
@testable import QuackKit

struct ProviderPlatformTests {
    @Test func rawValues() {
        #expect(ProviderPlatform.openAICompatible.rawValue == "openai_compatible")
        #expect(ProviderPlatform.anthropic.rawValue == "anthropic")
        #expect(ProviderPlatform.foundationModels.rawValue == "foundation_models")
        #expect(ProviderPlatform.gemini.rawValue == "gemini")
        #expect(ProviderPlatform.vertexGemini.rawValue == "vertex_gemini")
        #expect(ProviderPlatform.vertexAnthropic.rawValue == "vertex_anthropic")
        #expect(ProviderPlatform.mlx.rawValue == "mlx")
    }

    @Test func identifiers() {
        for platform in ProviderPlatform.allCases {
            #expect(platform.id == platform.rawValue)
        }
    }

    @Test func displayNames() {
        #expect(ProviderPlatform.openAICompatible.displayName == "OpenAI Compatible")
        #expect(ProviderPlatform.anthropic.displayName == "Anthropic")
        #expect(ProviderPlatform.foundationModels.displayName == "Apple Intelligence")
        #expect(ProviderPlatform.gemini.displayName == "Gemini")
        #expect(ProviderPlatform.vertexGemini.displayName == "Vertex AI (Gemini)")
        #expect(ProviderPlatform.vertexAnthropic.displayName == "Vertex AI (Claude)")
        #expect(ProviderPlatform.mlx.displayName == "MLX (On-Device)")
    }

    @Test func requiresAPIKey() {
        #expect(ProviderPlatform.openAICompatible.requiresAPIKey == true)
        #expect(ProviderPlatform.anthropic.requiresAPIKey == true)
        #expect(ProviderPlatform.gemini.requiresAPIKey == true)
        #expect(ProviderPlatform.foundationModels.requiresAPIKey == false)
        #expect(ProviderPlatform.vertexGemini.requiresAPIKey == false)
        #expect(ProviderPlatform.vertexAnthropic.requiresAPIKey == false)
        #expect(ProviderPlatform.mlx.requiresAPIKey == false)
    }

    @Test func requiresBaseURL() {
        #expect(ProviderPlatform.openAICompatible.requiresBaseURL == true)
        #expect(ProviderPlatform.anthropic.requiresBaseURL == true)
        #expect(ProviderPlatform.foundationModels.requiresBaseURL == false)
        #expect(ProviderPlatform.gemini.requiresBaseURL == false)
        #expect(ProviderPlatform.vertexGemini.requiresBaseURL == false)
        #expect(ProviderPlatform.vertexAnthropic.requiresBaseURL == false)
        #expect(ProviderPlatform.mlx.requiresBaseURL == false)
    }

    @Test func defaultBaseURL() {
        #expect(ProviderPlatform.anthropic.defaultBaseURL == "https://api.anthropic.com/v1")
        #expect(ProviderPlatform.openAICompatible.defaultBaseURL == nil)
        #expect(ProviderPlatform.gemini.defaultBaseURL == nil)
        #expect(ProviderPlatform.foundationModels.defaultBaseURL == nil)
    }

    @Test func supportsCaching() {
        #expect(ProviderPlatform.anthropic.supportsCaching == true)
        #expect(ProviderPlatform.vertexAnthropic.supportsCaching == true)
        #expect(ProviderPlatform.openAICompatible.supportsCaching == false)
        #expect(ProviderPlatform.gemini.supportsCaching == false)
        #expect(ProviderPlatform.foundationModels.supportsCaching == false)
        #expect(ProviderPlatform.mlx.supportsCaching == false)
    }

    @Test func defaultMaxTokens() {
        #expect(ProviderPlatform.anthropic.defaultMaxTokens == 40_000)
        #expect(ProviderPlatform.vertexAnthropic.defaultMaxTokens == 40_000)
        #expect(ProviderPlatform.gemini.defaultMaxTokens == 40_000)
        #expect(ProviderPlatform.vertexGemini.defaultMaxTokens == 40_000)
        #expect(ProviderPlatform.openAICompatible.defaultMaxTokens == 16_384)
        #expect(ProviderPlatform.foundationModels.defaultMaxTokens == 4_096)
        #expect(ProviderPlatform.mlx.defaultMaxTokens == 4_096)
    }

    @Test func modelsDevProviderIDs() {
        #expect(ProviderPlatform.openAICompatible.modelsDevProviderIDs.isEmpty)
        #expect(ProviderPlatform.anthropic.modelsDevProviderIDs == ["anthropic"])
        #expect(ProviderPlatform.gemini.modelsDevProviderIDs == ["google"])
        #expect(ProviderPlatform.vertexGemini.modelsDevProviderIDs == ["google-vertex", "google"])
        #expect(ProviderPlatform.vertexAnthropic.modelsDevProviderIDs == ["google-vertex-anthropic", "anthropic"])
        #expect(ProviderPlatform.foundationModels.modelsDevProviderIDs.isEmpty)
        #expect(ProviderPlatform.mlx.modelsDevProviderIDs.isEmpty)
    }

    @Test func knownModelsNotEmpty() {
        #expect(!ProviderPlatform.openAICompatible.knownModels.isEmpty)
        #expect(!ProviderPlatform.anthropic.knownModels.isEmpty)
        #expect(!ProviderPlatform.gemini.knownModels.isEmpty)
        #expect(!ProviderPlatform.vertexGemini.knownModels.isEmpty)
        #expect(!ProviderPlatform.vertexAnthropic.knownModels.isEmpty)
        #expect(ProviderPlatform.foundationModels.knownModels.isEmpty)
    }

    @Test func allCasesCount() {
        #expect(ProviderPlatform.allCases.count == 7)
    }

    @Test func codableRoundTrip() throws {
        for platform in ProviderPlatform.allCases {
            let data = try JSONEncoder().encode(platform)
            let decoded = try JSONDecoder().decode(ProviderPlatform.self, from: data)
            #expect(decoded == platform)
        }
    }

    @Test func makeClientReturnsNilWithoutFactory() {
        let result = ProviderPlatform.openAICompatible.makeClient(
            baseURL: URL(string: "https://api.openai.com/v1"),
            apiKey: "test-key",
            model: "gpt-4o",
            maxTokens: 4096,
            contextWindowSize: nil,
            reasoningConfig: nil,
            retryPolicy: RetryPolicy(maxAttempts: 3, baseDelay: .seconds(1), maxDelay: .seconds(30)),
            cachingEnabled: false,
            projectID: nil,
            location: nil
        )
        #expect(result == nil)
    }

    @Test func isCustomIcon() {
        #expect(ProviderPlatform.openAICompatible.isCustomIcon == true)
        #expect(ProviderPlatform.gemini.isCustomIcon == true)
        #expect(ProviderPlatform.anthropic.isCustomIcon == true)
        #expect(ProviderPlatform.foundationModels.isCustomIcon == false)
        #expect(ProviderPlatform.mlx.isCustomIcon == false)
    }
}

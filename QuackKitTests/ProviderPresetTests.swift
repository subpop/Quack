import Testing
import Foundation
@testable import QuackKit

struct ProviderPresetTests {
    @Test func allCasesCount() {
        #expect(ProviderPreset.allCases.count == 9)
    }

    @Test func displayNames() {
        #expect(ProviderPreset.ollama.displayName == "Ollama")
        #expect(ProviderPreset.openAI.displayName == "OpenAI")
        #expect(ProviderPreset.anthropic.displayName == "Anthropic")
        #expect(ProviderPreset.gemini.displayName == "Google Gemini")
        #expect(ProviderPreset.openRouter.displayName == "OpenRouter")
        #expect(ProviderPreset.groq.displayName == "Groq")
        #expect(ProviderPreset.together.displayName == "Together")
        #expect(ProviderPreset.mistral.displayName == "Mistral")
        #expect(ProviderPreset.custom.displayName == "Custom")
    }

    @Test func platforms() {
        #expect(ProviderPreset.ollama.platform == .openAICompatible)
        #expect(ProviderPreset.openAI.platform == .openAICompatible)
        #expect(ProviderPreset.anthropic.platform == .anthropic)
        #expect(ProviderPreset.gemini.platform == .gemini)
        #expect(ProviderPreset.openRouter.platform == .openAICompatible)
        #expect(ProviderPreset.groq.platform == .openAICompatible)
        #expect(ProviderPreset.together.platform == .openAICompatible)
        #expect(ProviderPreset.mistral.platform == .openAICompatible)
        #expect(ProviderPreset.custom.platform == .openAICompatible)
    }

    @Test func baseURLs() {
        #expect(ProviderPreset.ollama.baseURL == "http://localhost:11434/v1")
        #expect(ProviderPreset.openAI.baseURL == "https://api.openai.com/v1")
        #expect(ProviderPreset.anthropic.baseURL == "https://api.anthropic.com/v1")
        #expect(ProviderPreset.gemini.baseURL == nil)
        #expect(ProviderPreset.custom.baseURL == nil)
    }

    @Test func requiresAPIKey() {
        #expect(ProviderPreset.ollama.requiresAPIKey == false)
        #expect(ProviderPreset.openAI.requiresAPIKey == true)
        #expect(ProviderPreset.anthropic.requiresAPIKey == true)
        #expect(ProviderPreset.custom.requiresAPIKey == true)
    }

    @Test func defaultModels() {
        #expect(ProviderPreset.ollama.defaultModel == "llama3.2")
        #expect(ProviderPreset.openAI.defaultModel == "gpt-4o")
        #expect(ProviderPreset.anthropic.defaultModel == "claude-sonnet-4-20250514")
        #expect(ProviderPreset.gemini.defaultModel == "gemini-2.5-flash")
        #expect(ProviderPreset.openRouter.defaultModel == "")
        #expect(ProviderPreset.custom.defaultModel == "")
    }

    @Test func maxTokensValues() {
        #expect(ProviderPreset.anthropic.maxTokens == 40_000)
        #expect(ProviderPreset.openAI.maxTokens == 16_384)
        #expect(ProviderPreset.gemini.maxTokens == 40_000)
        #expect(ProviderPreset.groq.maxTokens == 8_192)
        #expect(ProviderPreset.ollama.maxTokens == 4_096)
    }

    @Test func cachingEnabledOnlyForAnthropic() {
        #expect(ProviderPreset.anthropic.cachingEnabled == true)
        for preset in ProviderPreset.allCases where preset != .anthropic {
            #expect(preset.cachingEnabled == false, "Expected caching disabled for \(preset.displayName)")
        }
    }

    @Test func retryDefaults() {
        for preset in ProviderPreset.allCases {
            #expect(preset.retryMaxAttempts == 3)
            #expect(preset.retryBaseDelay == 1.0)
            #expect(preset.retryMaxDelay == 30.0)
        }
    }

    @Test func modelsDevProviderIDs() {
        #expect(ProviderPreset.openAI.modelsDevProviderID == "openai")
        #expect(ProviderPreset.anthropic.modelsDevProviderID == "anthropic")
        #expect(ProviderPreset.gemini.modelsDevProviderID == "google")
        #expect(ProviderPreset.ollama.modelsDevProviderID == nil)
        #expect(ProviderPreset.custom.modelsDevProviderID == nil)
    }

    @Test func reasoningEffortNil() {
        for preset in ProviderPreset.allCases {
            #expect(preset.reasoningEffort == nil)
        }
    }

    @Test func customPresetIsCustomIcon() {
        #expect(ProviderPreset.custom.isCustomIcon == false)
        #expect(ProviderPreset.openAI.isCustomIcon == true)
        #expect(ProviderPreset.anthropic.isCustomIcon == true)
    }

    @Test func makeProfileCopiesValues() {
        let profile = ProviderPreset.openAI.makeProfile(sortOrder: 5)
        #expect(profile.name == "OpenAI")
        #expect(profile.platform == .openAICompatible)
        #expect(profile.sortOrder == 5)
        #expect(profile.baseURL == "https://api.openai.com/v1")
        #expect(profile.requiresAPIKey == true)
        #expect(profile.defaultModel == "gpt-4o")
        #expect(profile.maxTokens == 16_384)
        #expect(profile.cachingEnabled == false)
        #expect(profile.modelsDevProviderID == "openai")
    }

    @Test func makeProfileCustomName() {
        let profile = ProviderPreset.custom.makeProfile(sortOrder: 0)
        #expect(profile.name == "New Provider")
    }

    @Test func makeProfileAnthropicCaching() {
        let profile = ProviderPreset.anthropic.makeProfile(sortOrder: 1)
        #expect(profile.cachingEnabled == true)
        #expect(profile.platform == .anthropic)
    }

    @Test func contextWindowSizes() {
        #expect(ProviderPreset.openAI.contextWindowSize == 128_000)
        #expect(ProviderPreset.anthropic.contextWindowSize == 200_000)
        #expect(ProviderPreset.gemini.contextWindowSize == 1_048_576)
        #expect(ProviderPreset.ollama.contextWindowSize == nil)
        #expect(ProviderPreset.openRouter.contextWindowSize == nil)
    }
}

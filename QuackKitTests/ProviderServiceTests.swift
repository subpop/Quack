import Testing
import Foundation
@testable import QuackKit

struct ProviderServiceTests {
    @Test @MainActor func fallbackProfileReturnsFirstEnabled() {
        let service = ProviderService()
        let p1 = ProviderProfile(name: "Disabled", platform: .openAICompatible)
        p1.isEnabled = false
        let p2 = ProviderProfile(name: "Enabled", platform: .anthropic)
        p2.isEnabled = true

        let result = service.fallbackProfile(from: [p1, p2])
        #expect(result?.name == "Enabled")
    }

    @Test @MainActor func fallbackProfileReturnsFirstWhenNoneEnabled() {
        let service = ProviderService()
        let p1 = ProviderProfile(name: "Disabled1", platform: .openAICompatible)
        p1.isEnabled = false
        let p2 = ProviderProfile(name: "Disabled2", platform: .anthropic)
        p2.isEnabled = false

        let result = service.fallbackProfile(from: [p1, p2])
        #expect(result?.name == "Disabled1")
    }

    @Test @MainActor func fallbackProfileReturnsNilForEmptyList() {
        let service = ProviderService()
        let result = service.fallbackProfile(from: [])
        #expect(result == nil)
    }

    @Test @MainActor func resolvedModelFromSession() {
        let service = ProviderService()
        let session = ChatSession()
        session.modelIdentifier = "gpt-4o-mini"

        let model = service.resolvedModel(for: session, profiles: [])
        #expect(model == "gpt-4o-mini")
    }

    @Test @MainActor func resolvedModelFallsBackToProfile() {
        let service = ProviderService()
        let profile = ProviderProfile(name: "OpenAI", platform: .openAICompatible, defaultModel: "gpt-4o")
        let session = ChatSession()
        session.providerID = profile.id

        let model = service.resolvedModel(for: session, profiles: [profile])
        #expect(model == "gpt-4o")
    }

    @Test @MainActor func resolvedModelFallsBackToUnknown() {
        let service = ProviderService()
        let session = ChatSession()
        let model = service.resolvedModel(for: session, profiles: [])
        #expect(model == "unknown")
    }

    @Test @MainActor func resolvedProfileFromSession() {
        let service = ProviderService()
        let profile = ProviderProfile(name: "Anthropic", platform: .anthropic)
        let session = ChatSession()
        session.providerID = profile.id

        let resolved = service.resolvedProfile(for: session, profiles: [profile])
        #expect(resolved?.id == profile.id)
    }

    @Test @MainActor func resolvedProfileFallsBack() {
        let service = ProviderService()
        let profile = ProviderProfile(name: "Default", platform: .openAICompatible)
        let session = ChatSession()

        let resolved = service.resolvedProfile(for: session, profiles: [profile])
        #expect(resolved?.id == profile.id)
    }

    @Test @MainActor func mlxLoadStateIdle() {
        let service = ProviderService()
        if case .idle = service.mlxLoadState {} else {
            Issue.record("Expected idle MLX load state")
        }
    }

    @Test @MainActor func invalidateCache() {
        let service = ProviderService()
        service.invalidateCache()
    }
}

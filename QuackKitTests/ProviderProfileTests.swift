import Testing
import Foundation
@testable import QuackKit

struct ProviderProfileTests {
    @Test func initDefaults() {
        let profile = ProviderProfile(name: "Test", platform: .openAICompatible)
        #expect(profile.name == "Test")
        #expect(profile.platform == .openAICompatible)
        #expect(profile.isEnabled == true)
        #expect(profile.sortOrder == 0)
        #expect(profile.requiresAPIKey == true)
        #expect(profile.defaultModel == "")
        #expect(profile.maxTokens == 4096)
        #expect(profile.cachingEnabled == false)
        #expect(profile.retryMaxAttempts == 3)
        #expect(profile.retryBaseDelay == 1.0)
        #expect(profile.retryMaxDelay == 30.0)
    }

    @Test func platformSetterUpdatesIcon() {
        let profile = ProviderProfile(name: "Test", platform: .openAICompatible)
        profile.platform = .anthropic
        #expect(profile.kindRaw == "anthropic")
        #expect(profile.iconName == "anthropic")
        #expect(profile.iconIsCustom == true)
        #expect(profile.iconColorName == "orange")
    }

    @Test func builtInProfiles() {
        let profiles = ProviderProfile.builtInProfiles()
        #expect(!profiles.isEmpty)
        #expect(profiles.contains(where: { $0.platform == .foundationModels }))
    }

    @Test func previewProfiles() {
        let profiles = ProviderProfile.previewProfiles()
        #expect(profiles.count >= 5)
        let platforms = Set(profiles.map(\.platform))
        #expect(platforms.contains(.openAICompatible))
        #expect(platforms.contains(.anthropic))
        #expect(platforms.contains(.foundationModels))
    }

    @Test func iconColor() {
        let profile = ProviderProfile(
            name: "Test", platform: .openAICompatible,
            iconName: "openai", iconIsCustom: true, iconColorName: "green"
        )
        _ = profile.iconColor
    }
}

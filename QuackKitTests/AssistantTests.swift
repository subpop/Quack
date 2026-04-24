import Testing
import Foundation
@testable import QuackKit

struct AssistantTests {
    @Test func initDefaults() {
        let assistant = Assistant()
        #expect(assistant.name == "")
        #expect(assistant.systemPrompt == nil)
        #expect(assistant.isDefault == false)
        #expect(assistant.sortOrder == 0)
    }

    @Test func initWithValues() {
        let assistant = Assistant(
            name: "Coder",
            systemPrompt: "You are a coding assistant.",
            isDefault: true,
            sortOrder: 3
        )
        #expect(assistant.name == "Coder")
        #expect(assistant.systemPrompt == "You are a coding assistant.")
        #expect(assistant.isDefault == true)
        #expect(assistant.sortOrder == 3)
    }

    @Test func providerIDRoundTrip() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.providerID == nil)

        let uuid = UUID()
        assistant.providerID = uuid
        #expect(assistant.providerID == uuid)
        #expect(assistant.providerIDString == uuid.uuidString)

        assistant.providerID = nil
        #expect(assistant.providerID == nil)
        #expect(assistant.providerIDString == nil)
    }

    @Test func enabledMCPServerIDsRoundTrip() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.enabledMCPServerIDs == nil)

        let id1 = UUID()
        let id2 = UUID()
        assistant.enabledMCPServerIDs = [id1, id2]
        let ids = assistant.enabledMCPServerIDs!
        #expect(ids.contains(id1))
        #expect(ids.contains(id2))
    }

    @Test func enabledBuiltInToolIDsRoundTrip() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.enabledBuiltInToolIDs == nil)

        assistant.enabledBuiltInToolIDs = ["builtin-read_file", "builtin-write_file"]
        #expect(assistant.enabledBuiltInToolIDs == ["builtin-read_file", "builtin-write_file"])
    }

    @Test func toolPermissionDefaultsRoundTrip() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.toolPermissionDefaults == nil)

        assistant.toolPermissionDefaults = ["tool_a": .always, "tool_b": .deny]
        let defaults = assistant.toolPermissionDefaults!
        #expect(defaults["tool_a"] == .always)
        #expect(defaults["tool_b"] == .deny)
    }

    @Test func toolPermissionDefaultsSetNil() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = ["tool_a": .always]
        assistant.toolPermissionDefaults = nil
        #expect(assistant.toolPermissionDefaultsJSON == nil)
    }

    @Test func toolPermissionDefaultsSetEmpty() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = [:]
        #expect(assistant.toolPermissionDefaultsJSON == nil)
    }

    @Test func effectivePermission() {
        let assistant = Assistant(name: "Test")
        assistant.toolPermissionDefaults = ["tool_a": .always]

        #expect(assistant.effectivePermission(for: "tool_a", serverDefault: .ask) == .always)
        #expect(assistant.effectivePermission(for: "tool_b", serverDefault: .ask) == .ask)
        #expect(assistant.effectivePermission(for: "tool_b", serverDefault: .deny) == .deny)
    }

    @Test func setToolPermission() {
        let assistant = Assistant(name: "Test")

        assistant.setToolPermission(.always, for: "tool_a", serverDefault: .ask)
        #expect(assistant.toolPermissionDefaults?["tool_a"] == .always)

        assistant.setToolPermission(.ask, for: "tool_a", serverDefault: .ask)
        #expect(assistant.toolPermissionDefaults == nil)
    }

    @Test func defaultAssistant() {
        let assistant = Assistant.defaultAssistant()
        #expect(assistant.name == "General")
        #expect(assistant.systemPrompt == "You are a helpful assistant.")
        #expect(assistant.isDefault == true)
        #expect(assistant.sortOrder == 0)
        #expect(assistant.iconName == "bubble.left.and.bubble.right.fill")
        #expect(assistant.colorRaw == "blue")
    }

    @Test func codingAssistant() {
        let assistant = Assistant.codingAssistant()
        #expect(assistant.name == "Coding")
        #expect(assistant.systemPrompt?.contains("expert software engineering assistant") == true)
        #expect(assistant.isDefault == false)
        #expect(assistant.sortOrder == 1)
        #expect(assistant.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(assistant.colorRaw == "purple")
    }

    @Test func resolvedIconDefault() {
        let assistant = Assistant(name: "Test")
        #expect(assistant.resolvedIcon == "person.crop.circle.fill")
    }

    @Test func resolvedIconCustom() {
        let assistant = Assistant(name: "Test")
        assistant.iconName = "star.fill"
        #expect(assistant.resolvedIcon == "star.fill")
    }

    @Test func colorPalette() {
        #expect(!Assistant.colorPalette.isEmpty)
        #expect(Assistant.colorPalette.keys.contains("blue"))
        #expect(Assistant.colorPalette.keys.contains("red"))
        #expect(Assistant.colorPalette.keys.contains("green"))
    }

    @Test func colorKeys() {
        #expect(!Assistant.colorKeys.isEmpty)
        for key in Assistant.colorKeys {
            #expect(Assistant.colorPalette[key] != nil, "Color key '\(key)' not in palette")
        }
    }

    @Test func iconChoices() {
        #expect(!Assistant.iconChoices.isEmpty)
        #expect(Assistant.iconChoices.contains("person.crop.circle.fill"))
        #expect(Assistant.iconChoices.contains("sparkles"))
        #expect(Assistant.iconChoices.contains("terminal.fill"))
    }
}

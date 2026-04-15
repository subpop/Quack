import Testing
import Foundation
@testable import QuackKit

struct ChatSessionTests {
    @Test func initDefaults() {
        let session = ChatSession()
        #expect(session.title == "New Chat")
        #expect(session.isArchived == false)
        #expect(session.isPinned == false)
        #expect(session.providerID == nil)
        #expect(session.modelIdentifier == nil)
        #expect(session.systemPrompt == nil)
        #expect(session.temperature == nil)
        #expect(session.maxTokens == nil)
    }

    @Test func initWithTitle() {
        let session = ChatSession(title: "My Chat")
        #expect(session.title == "My Chat")
    }

    @Test func providerIDRoundTrip() {
        let session = ChatSession()
        let uuid = UUID()
        session.providerID = uuid
        #expect(session.providerID == uuid)
        session.providerID = nil
        #expect(session.providerID == nil)
    }

    @Test func assistantIDRoundTrip() {
        let session = ChatSession()
        let uuid = UUID()
        session.assistantID = uuid
        #expect(session.assistantID == uuid)
        session.assistantID = nil
        #expect(session.assistantID == nil)
    }

    @Test func enabledMCPServerIDsRoundTrip() {
        let session = ChatSession()
        let id1 = UUID()
        let id2 = UUID()
        session.enabledMCPServerIDs = [id1, id2]
        let ids = session.enabledMCPServerIDs!
        #expect(ids.count == 2)
        #expect(ids.contains(id1))
        #expect(ids.contains(id2))
    }

    @Test func enabledBuiltInToolIDsRoundTrip() {
        let session = ChatSession()
        session.enabledBuiltInToolIDs = ["builtin-read_file", "builtin-run_command"]
        #expect(session.enabledBuiltInToolIDs == ["builtin-read_file", "builtin-run_command"])
    }

    @Test func toolPermissionOverridesRoundTrip() {
        let session = ChatSession()
        #expect(session.toolPermissionOverrides == nil)

        session.toolPermissionOverrides = ["my_tool": .always, "other_tool": .deny]
        let overrides = session.toolPermissionOverrides!
        #expect(overrides["my_tool"] == .always)
        #expect(overrides["other_tool"] == .deny)
    }

    @Test func toolPermissionOverridesSetEmpty() {
        let session = ChatSession()
        session.toolPermissionOverrides = ["tool": .always]
        session.toolPermissionOverrides = [:]
        #expect(session.toolPermissionOverridesJSON == nil)
    }

    @Test func effectivePermission() {
        let session = ChatSession()
        session.toolPermissionOverrides = ["tool_a": .deny]

        #expect(session.effectivePermission(for: "tool_a", serverDefault: .ask) == .deny)
        #expect(session.effectivePermission(for: "tool_b", serverDefault: .ask) == .ask)
    }

    @Test func setToolPermission() {
        let session = ChatSession()

        session.setToolPermission(.always, for: "tool_a", serverDefault: .ask)
        #expect(session.toolPermissionOverrides?["tool_a"] == .always)

        session.setToolPermission(.ask, for: "tool_a", serverDefault: .ask)
        #expect(session.toolPermissionOverrides == nil)
    }

    @Test func initFromAssistant() {
        let assistant = Assistant(name: "Coder", systemPrompt: "Code things", isDefault: false)
        assistant.temperature = 0.7
        assistant.maxTokens = 8192
        assistant.reasoningEffort = "medium"
        assistant.maxToolRounds = 5
        assistant.enabledBuiltInToolIDsRaw = "builtin-read_file,builtin-write_file"

        let session = ChatSession(title: "Test", assistant: assistant)
        #expect(session.assistantID == assistant.id)
        #expect(session.systemPrompt == "Code things")
        #expect(session.temperature == 0.7)
        #expect(session.maxTokens == 8192)
        #expect(session.reasoningEffort == "medium")
        #expect(session.maxToolRounds == 5)
        #expect(session.enabledBuiltInToolIDsRaw == "builtin-read_file,builtin-write_file")
    }

    @Test func initFromProfile() {
        let profile = ProviderProfile(
            name: "OpenAI",
            platform: .openAICompatible,
            defaultModel: "gpt-4o",
            maxTokens: 16384,
            reasoningEffort: "high"
        )
        let session = ChatSession(title: "Test", profile: profile)
        #expect(session.providerID == profile.id)
        #expect(session.modelIdentifier == "gpt-4o")
        #expect(session.maxTokens == 16384)
        #expect(session.reasoningEffort == "high")
    }
}

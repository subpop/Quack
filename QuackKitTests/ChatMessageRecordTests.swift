import Testing
import Foundation
@testable import QuackKit

struct ChatMessageRecordTests {
    @Test func initSetsProperties() {
        let record = ChatMessageRecord(role: .user, content: "Hello")
        #expect(record.role == .user)
        #expect(record.content == "Hello")
        #expect(record.roleRaw == "user")
        #expect(record.reasoning == nil)
        #expect(record.inputTokens == nil)
        #expect(record.outputTokens == nil)
        #expect(record.reasoningTokens == nil)
        #expect(record.toolCallsJSON == nil)
        #expect(record.contentSegmentsJSON == nil)
        #expect(record.toolCallId == nil)
        #expect(record.toolName == nil)
    }

    @Test func roleComputedProperty() {
        let record = ChatMessageRecord(role: .assistant, content: "Hi")
        #expect(record.role == .assistant)
        #expect(record.roleRaw == "assistant")

        record.role = .tool
        #expect(record.role == .tool)
        #expect(record.roleRaw == "tool")
    }

    @Test func roleDefaultsToUserForInvalidRaw() {
        let record = ChatMessageRecord(role: .user, content: "test")
        record.roleRaw = "invalid_role"
        #expect(record.role == .user)
    }

    @Test func initWithAllParameters() {
        let record = ChatMessageRecord(
            role: .assistant,
            content: "response",
            reasoning: "thinking...",
            inputTokens: 100,
            outputTokens: 200,
            reasoningTokens: 50,
            toolCallsJSON: "[{}]",
            contentSegmentsJSON: "[{}]",
            toolCallId: "tc_1",
            toolName: "readFile"
        )
        #expect(record.reasoning == "thinking...")
        #expect(record.inputTokens == 100)
        #expect(record.outputTokens == 200)
        #expect(record.reasoningTokens == 50)
        #expect(record.toolCallsJSON == "[{}]")
        #expect(record.contentSegmentsJSON == "[{}]")
        #expect(record.toolCallId == "tc_1")
        #expect(record.toolName == "readFile")
    }

    @Test func uniqueIDs() {
        let r1 = ChatMessageRecord(role: .user, content: "a")
        let r2 = ChatMessageRecord(role: .user, content: "b")
        #expect(r1.id != r2.id)
    }
}

import Testing
import Foundation
@testable import QuackKit

@MainActor
struct MessageConverterTests {
    @Test func convertUserMessage() {
        let record = ChatMessageRecord(role: .user, content: "Hello")
        let messages = MessageConverter.toChatMessages([record])
        #expect(messages.count == 1)
        if case .user(let text) = messages[0] {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected user message")
        }
    }

    @Test func convertSystemMessage() {
        let record = ChatMessageRecord(role: .system, content: "You are helpful")
        let messages = MessageConverter.toChatMessages([record])
        #expect(messages.count == 1)
        if case .system(let text) = messages[0] {
            #expect(text == "You are helpful")
        } else {
            Issue.record("Expected system message")
        }
    }

    @Test func convertAssistantMessage() {
        let record = ChatMessageRecord(role: .assistant, content: "Hi there!")
        let messages = MessageConverter.toChatMessages([record])
        #expect(messages.count == 1)
        if case .assistant(let msg) = messages[0] {
            #expect(msg.content == "Hi there!")
            #expect(msg.toolCalls.isEmpty)
        } else {
            Issue.record("Expected assistant message")
        }
    }

    @Test func convertToolMessage() {
        // Tool message must be paired with a preceding assistant message containing the tool_use
        // to survive repair. Create a proper pair.
        let toolCallsJSON = """
        [{"id":"tc_1","name":"readFile","arguments":"{}"}]
        """
        let assistantRecord = ChatMessageRecord(
            role: .assistant,
            content: "",
            toolCallsJSON: toolCallsJSON
        )
        let toolRecord = ChatMessageRecord(
            role: .tool,
            content: "file contents",
            toolCallId: "tc_1",
            toolName: "readFile"
        )
        let messages = MessageConverter.toChatMessages([assistantRecord, toolRecord])
        // Should have assistant + tool
        #expect(messages.count == 2)
        if case .tool(let id, let name, let content) = messages[1] {
            #expect(id == "tc_1")
            #expect(name == "readFile")
            #expect(content == "file contents")
        } else {
            Issue.record("Expected tool message")
        }
    }

    @Test func toolMessageWithoutIdIsSkipped() {
        let record = ChatMessageRecord(role: .tool, content: "orphan")
        let messages = MessageConverter.toChatMessages([record])
        #expect(messages.isEmpty)
    }

    @Test func convertAssistantWithToolCalls() {
        let toolCallsJSON = """
        [{"id":"tc_1","name":"readFile","arguments":"{\\"path\\":\\"/tmp/test\\"}"}]
        """
        let assistantRecord = ChatMessageRecord(
            role: .assistant,
            content: "Let me read that file.",
            toolCallsJSON: toolCallsJSON
        )
        // Add a matching tool result to prevent repair from adding a synthetic one
        let toolRecord = ChatMessageRecord(
            role: .tool,
            content: "file contents here",
            toolCallId: "tc_1",
            toolName: "readFile"
        )
        let messages = MessageConverter.toChatMessages([assistantRecord, toolRecord])
        // Should have assistant + tool (both preserved since they're paired)
        #expect(messages.count == 2)
        if case .assistant(let msg) = messages[0] {
            #expect(msg.toolCalls.count == 1)
            #expect(msg.toolCalls[0].id == "tc_1")
            #expect(msg.toolCalls[0].name == "readFile")
        } else {
            Issue.record("Expected assistant message with tool calls")
        }
    }

    @Test func convertAssistantWithReasoning() {
        let record = ChatMessageRecord(
            role: .assistant,
            content: "The answer is 42.",
            reasoning: "I need to think about this..."
        )
        let messages = MessageConverter.toChatMessages([record])
        if case .assistant(let msg) = messages[0] {
            #expect(msg.reasoning?.content == "I need to think about this...")
        } else {
            Issue.record("Expected assistant message")
        }
    }

    @Test func convertAssistantWithTokenUsage() {
        let record = ChatMessageRecord(
            role: .assistant,
            content: "Response",
            inputTokens: 100,
            outputTokens: 50,
            reasoningTokens: 20
        )
        let messages = MessageConverter.toChatMessages([record])
        if case .assistant(let msg) = messages[0] {
            #expect(msg.tokenUsage?.input == 100)
            #expect(msg.tokenUsage?.output == 50)
            #expect(msg.tokenUsage?.reasoning == 20)
        } else {
            Issue.record("Expected assistant message")
        }
    }

    @Test func repairOrphanedToolResults() {
        let assistantRecord = ChatMessageRecord(role: .assistant, content: "Hi")
        let orphanToolRecord = ChatMessageRecord(
            role: .tool, content: "orphan result",
            toolCallId: "nonexistent_tc", toolName: "someTool"
        )
        let messages = MessageConverter.toChatMessages([assistantRecord, orphanToolRecord])
        #expect(messages.count == 1)
        if case .assistant = messages[0] {} else {
            Issue.record("Expected only assistant message to remain")
        }
    }

    @Test func repairMissingToolResults() {
        let toolCallsJSON = """
        [{"id":"tc_1","name":"readFile","arguments":"{}"}]
        """
        let assistantRecord = ChatMessageRecord(
            role: .assistant,
            content: "Reading file...",
            toolCallsJSON: toolCallsJSON
        )
        let messages = MessageConverter.toChatMessages([assistantRecord])
        #expect(messages.count == 2)
        if case .tool(let id, let name, let content) = messages[1] {
            #expect(id == "tc_1")
            #expect(name == "readFile")
            #expect(content == "Tool call was interrupted.")
        } else {
            Issue.record("Expected synthetic tool result")
        }
    }

    @Test func toRecordFromAssistantMessage() {
        let assistantMsg = AssistantMessage(
            content: "Hello!",
            toolCalls: [ToolCall(id: "tc_1", name: "tool", arguments: "{}")],
            tokenUsage: TokenUsage(input: 10, output: 20, reasoning: 5),
            reasoning: ReasoningContent(content: "thinking", signature: nil)
        )
        let record = MessageConverter.toRecord(from: assistantMsg)
        #expect(record.role == .assistant)
        #expect(record.content == "Hello!")
        #expect(record.reasoning == "thinking")
        #expect(record.inputTokens == 10)
        #expect(record.outputTokens == 20)
        #expect(record.reasoningTokens == 5)
        #expect(record.toolCallsJSON != nil)
    }

    @Test func multipleMessagesConversion() {
        let records = [
            ChatMessageRecord(role: .system, content: "System prompt"),
            ChatMessageRecord(role: .user, content: "What is 2+2?"),
            ChatMessageRecord(role: .assistant, content: "4"),
        ]
        let messages = MessageConverter.toChatMessages(records)
        #expect(messages.count == 3)
    }
}

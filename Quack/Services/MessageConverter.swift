import Foundation
import AgentRunKit

enum MessageConverter {
    /// Convert persisted SwiftData records to AgentRunKit ChatMessages for API calls.
    static func toChatMessages(_ records: [ChatMessageRecord]) -> [ChatMessage] {
        records.compactMap { record in
            switch record.role {
            case .system:
                return .system(record.content)
            case .user:
                return .user(record.content)
            case .assistant:
                let toolCalls = decodeToolCalls(from: record.toolCallsJSON)
                let reasoning: ReasoningContent? = if let text = record.reasoning {
                    ReasoningContent(content: text, signature: nil)
                } else {
                    nil
                }
                let tokenUsage: TokenUsage? = if let input = record.inputTokens {
                    TokenUsage(
                        input: input,
                        output: record.outputTokens ?? 0,
                        reasoning: record.reasoningTokens ?? 0
                    )
                } else {
                    nil
                }
                let message = AssistantMessage(
                    content: record.content,
                    toolCalls: toolCalls,
                    tokenUsage: tokenUsage,
                    reasoning: reasoning
                )
                return .assistant(message)
            case .tool:
                guard let toolCallId = record.toolCallId,
                      let toolName = record.toolName
                else { return nil }
                return .tool(id: toolCallId, name: toolName, content: record.content)
            }
        }
    }

    /// Create a ChatMessageRecord from an AssistantMessage response.
    static func toRecord(from assistant: AssistantMessage) -> ChatMessageRecord {
        let toolCallsJSON = encodeToolCalls(assistant.toolCalls)
        return ChatMessageRecord(
            role: .assistant,
            content: assistant.content,
            reasoning: assistant.reasoning?.content,
            inputTokens: assistant.tokenUsage?.input,
            outputTokens: assistant.tokenUsage?.output,
            reasoningTokens: assistant.tokenUsage?.reasoning,
            toolCallsJSON: toolCallsJSON
        )
    }

    // MARK: - Tool Call Serialization

    private struct ToolCallData: Codable {
        let id: String
        let name: String
        let arguments: String
    }

    private static func decodeToolCalls(from json: String?) -> [ToolCall] {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let calls = try? JSONDecoder().decode([ToolCallData].self, from: data)
        else { return [] }
        return calls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) }
    }

    private static func encodeToolCalls(_ toolCalls: [ToolCall]) -> String? {
        guard !toolCalls.isEmpty else { return nil }
        let data = toolCalls.map { ToolCallData(id: $0.id, name: $0.name, arguments: $0.arguments) }
        guard let jsonData = try? JSONEncoder().encode(data),
              let json = String(data: jsonData, encoding: .utf8)
        else { return nil }
        return json
    }
}

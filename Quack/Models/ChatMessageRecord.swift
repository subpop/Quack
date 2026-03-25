import Foundation
import SwiftData

@Model
final class ChatMessageRecord {
    var id: UUID
    var roleRaw: String
    var content: String
    var timestamp: Date

    // Token usage (for assistant messages)
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?

    // Reasoning content (for thinking models)
    var reasoning: String?

    // Tool call data (for assistant messages with tool calls)
    var toolCallsJSON: String?

    // Tool result metadata (for tool role messages)
    var toolCallId: String?
    var toolName: String?

    var session: ChatSession?

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        role: MessageRole,
        content: String,
        reasoning: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        toolCallsJSON: String? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = Date()
        self.reasoning = reasoning
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.toolCallsJSON = toolCallsJSON
        self.toolCallId = toolCallId
        self.toolName = toolName
    }
}

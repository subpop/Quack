// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

    /// Ordered segments describing how text and tool calls interleave.
    /// JSON array of objects: `{"type":"text","value":"..."}` or `{"type":"toolCall","id":"..."}`.
    /// When nil, legacy layout is used (tool calls first, then content).
    var contentSegmentsJSON: String?

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
        contentSegmentsJSON: String? = nil,
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
        self.contentSegmentsJSON = contentSegmentsJSON
        self.toolCallId = toolCallId
        self.toolName = toolName
    }
}

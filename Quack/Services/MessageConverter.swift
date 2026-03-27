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
import AgentRunKit

enum MessageConverter {
    /// Convert persisted SwiftData records to AgentRunKit ChatMessages for API calls.
    static func toChatMessages(_ records: [ChatMessageRecord]) -> [ChatMessage] {
        var messages = records.compactMap { record -> ChatMessage? in
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

        // Ensure every tool_use has a matching tool_result and vice versa.
        // This prevents API errors from corrupted persistence (e.g. stream
        // cancellation during tool execution).
        repairToolPairing(&messages)

        return messages
    }

    /// Adds synthetic tool_result messages for orphaned tool_use blocks and
    /// removes orphaned tool_result messages that have no matching tool_use.
    private static func repairToolPairing(_ messages: inout [ChatMessage]) {
        // Collect all tool_use ids from assistant messages and all tool_result
        // ids from tool messages.
        var toolUseIds = Set<String>()
        var toolResultIds = Set<String>()

        for message in messages {
            switch message {
            case .assistant(let msg):
                for tc in msg.toolCalls {
                    toolUseIds.insert(tc.id)
                }
            case .tool(let id, _, _):
                toolResultIds.insert(id)
            default:
                break
            }
        }

        // Remove tool_result messages that have no matching tool_use
        let orphanedResults = toolResultIds.subtracting(toolUseIds)
        if !orphanedResults.isEmpty {
            messages.removeAll { msg in
                if case .tool(let id, _, _) = msg {
                    return orphanedResults.contains(id)
                }
                return false
            }
        }

        // Add synthetic tool_result messages for tool_use without results.
        // Insert them right after the assistant message that contains the
        // tool_use, maintaining correct message ordering.
        let missingResults = toolUseIds.subtracting(toolResultIds)
        if !missingResults.isEmpty {
            var insertions: [(index: Int, message: ChatMessage)] = []
            for (i, message) in messages.enumerated() {
                if case .assistant(let msg) = message {
                    for tc in msg.toolCalls where missingResults.contains(tc.id) {
                        insertions.append((
                            index: i + 1,
                            message: .tool(id: tc.id, name: tc.name, content: "Tool call was interrupted.")
                        ))
                    }
                }
            }
            // Insert in reverse order so indices remain valid
            for insertion in insertions.reversed() {
                messages.insert(insertion.message, at: min(insertion.index, messages.count))
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
        let arguments: String?

        // Also decode optional fields from CompletedToolCallData format
        // so the same struct can parse both serialization formats.
        let result: String?
        let isError: Bool?

        init(id: String, name: String, arguments: String) {
            self.id = id
            self.name = name
            self.arguments = arguments
            self.result = nil
            self.isError = nil
        }
    }

    private static func decodeToolCalls(from json: String?) -> [ToolCall] {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let calls = try? JSONDecoder().decode([ToolCallData].self, from: data)
        else { return [] }
        return calls.map { ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments ?? "{}") }
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

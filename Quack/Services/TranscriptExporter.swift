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

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Converts a `ChatSession` transcript into Markdown and presents a save panel.
enum TranscriptExporter {

    // MARK: - Markdown Generation

    /// Generate a full Markdown transcript of the given chat session.
    ///
    /// - Parameters:
    ///   - session: The chat session to export.
    ///   - modelName: A display string for the model (e.g. "claude-sonnet-4-20250514"), or nil.
    ///   - providerName: A display string for the provider (e.g. "Anthropic"), or nil.
    /// - Returns: A Markdown-formatted string representing the full conversation.
    static func exportMarkdown(
        session: ChatSession,
        modelName: String? = nil,
        providerName: String? = nil
    ) -> String {
        var lines: [String] = []

        // -- Metadata header --
        lines.append("# \(session.title)")
        lines.append("")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: session.createdAt)
        lines.append("**Date:** \(dateString)  ")

        let provider = providerName ?? "Unknown"
        let model = modelName ?? "Unknown"
        lines.append("**Model:** \(provider) · \(model)")
        lines.append("")

        // -- Messages --
        let sortedMessages = session.sortedMessages

        // Build a lookup of tool-role messages keyed by toolCallId so we can
        // inline tool results inside assistant messages.
        var toolResultsByCallID: [String: ChatMessageRecord] = [:]
        for message in sortedMessages where message.role == .tool {
            if let callID = message.toolCallId {
                toolResultsByCallID[callID] = message
            }
        }

        for message in sortedMessages {
            switch message.role {
            case .user:
                lines.append("---")
                lines.append("")
                lines.append("## User")
                lines.append("")
                lines.append(message.content)
                lines.append("")

            case .assistant:
                lines.append("---")
                lines.append("")
                lines.append("## Assistant")
                lines.append("")

                // Reasoning (thinking)
                if let reasoning = message.reasoning, !reasoning.isEmpty {
                    lines.append("> [!NOTE]")
                    lines.append("> **Thinking**")
                    lines.append(">")
                    for reasoningLine in reasoning.split(separator: "\n", omittingEmptySubsequences: false) {
                        lines.append("> \(reasoningLine)")
                    }
                    lines.append("")
                }

                // Decode tool calls and content segments
                let toolCalls = ChatService.decodeCompletedToolCalls(from: message.toolCallsJSON)
                let segments = ChatService.decodeContentSegments(from: message.contentSegmentsJSON)

                if !segments.isEmpty {
                    // Interleaved rendering
                    let toolCallMap = Dictionary(uniqueKeysWithValues: toolCalls.map { ($0.id, $0) })
                    for segment in segments {
                        switch segment.type {
                        case "text":
                            if !segment.value.isEmpty {
                                lines.append(segment.value)
                                lines.append("")
                            }
                        case "toolCall":
                            if let tc = toolCallMap[segment.value] {
                                lines.append(contentsOf: renderToolCall(tc, toolResultsByCallID: toolResultsByCallID))
                                lines.append("")
                            }
                        default:
                            break
                        }
                    }
                } else {
                    // Legacy layout: tool calls first, then content
                    for tc in toolCalls {
                        lines.append(contentsOf: renderToolCall(tc, toolResultsByCallID: toolResultsByCallID))
                        lines.append("")
                    }

                    if !message.content.isEmpty {
                        lines.append(message.content)
                        lines.append("")
                    }
                }

            case .system:
                lines.append("---")
                lines.append("")
                lines.append("## System")
                lines.append("")
                lines.append("*\(message.content)*")
                lines.append("")

            case .tool:
                // Tool results are rendered inline within their parent assistant
                // message; skip standalone rendering.
                continue
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Tool Call Rendering

    private static func renderToolCall(
        _ toolCall: ChatService.CompletedToolCallData,
        toolResultsByCallID: [String: ChatMessageRecord]
    ) -> [String] {
        var lines: [String] = []
        let label = toolCall.isError ? "Tool Call: \(toolCall.name) (Error)" : toolCall.name
        lines.append("<details>")
        lines.append("<summary>\(label)</summary>")
        lines.append("")

        if let arguments = toolCall.arguments, !arguments.isEmpty {
            lines.append("**Arguments:**")
            lines.append("")
            lines.append("```json")
            // Pretty-print the JSON if possible
            if let data = arguments.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: pretty, encoding: .utf8)
            {
                lines.append(prettyString)
            } else {
                lines.append(arguments)
            }
            lines.append("```")
            lines.append("")
        }

        // Prefer the tool-role message result (which is the actual MCP response),
        // falling back to the result stored on the CompletedToolCallData.
        let resultContent: String? = toolResultsByCallID[toolCall.id]?.content ?? toolCall.result

        if let result = resultContent, !result.isEmpty {
            lines.append("**Result:**")
            lines.append("")
            lines.append("```")
            lines.append(result)
            lines.append("```")
            lines.append("")
        }

        lines.append("</details>")
        return lines
    }

    // MARK: - Save Panel

    /// Present a save panel and write the session transcript as a Markdown file.
    ///
    /// - Parameters:
    ///   - session: The chat session to export.
    ///   - modelName: Display name for the model.
    ///   - providerName: Display name for the provider.
    @MainActor
    static func presentSavePanel(
        session: ChatSession,
        modelName: String? = nil,
        providerName: String? = nil
    ) {
        let markdown = exportMarkdown(
            session: session,
            modelName: modelName,
            providerName: providerName
        )

        let panel = NSSavePanel()
        panel.title = "Export Transcript"
        panel.nameFieldStringValue = sanitizedFilename(session.title) + ".md"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Helpers

    /// Sanitize a string for use as a filename, removing or replacing characters
    /// that are invalid on macOS filesystems.
    private static func sanitizedFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let sanitized = name.unicodeScalars
            .filter { !invalidCharacters.contains($0) }
            .map { Character($0) }
        let result = String(sanitized).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Chat Export" : result
    }
}

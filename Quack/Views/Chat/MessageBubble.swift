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

import SwiftUI
import SwiftData

struct MessageBubble: View {
    let message: ChatMessageRecord
    var onResubmit: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var hoverDispatch: DispatchWorkItem?

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .system:
            systemBubble
        case .tool:
            toolBubble
        }
    }

    // MARK: - User Message

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(.white)

            if isHovering {
                HStack(spacing: 6) {
                    if let onResubmit {
                        Button {
                            onResubmit()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Resubmit this message and regenerate response")
                    }

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 60)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .onHover { hovering in
            if hovering {
                hoverDispatch?.cancel()
                hoverDispatch = nil
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = true
                }
            } else {
                let work = DispatchWorkItem { [self] in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovering = false
                    }
                }
                hoverDispatch = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
        }
    }

    // MARK: - Assistant Message

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Reasoning (collapsible)
            if let reasoning = message.reasoning, !reasoning.isEmpty {
                ReasoningView(reasoning: reasoning, isStreaming: false)
            }

            // Interleaved content: use segment ordering if available, otherwise
            // fall back to legacy layout (tool calls first, then text).
            let toolCalls = ChatService.decodeCompletedToolCalls(from: message.toolCallsJSON)
            let segments = ChatService.decodeContentSegments(from: message.contentSegmentsJSON)

            if !segments.isEmpty {
                // Render in interleaved order
                let toolCallMap = Dictionary(uniqueKeysWithValues: toolCalls.map { ($0.id, $0) })
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment.type {
                    case "text":
                        if !segment.value.isEmpty {
                            Text(MarkdownRenderer.renderFull(segment.value))
                                .textSelection(.enabled)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Color(.controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        }
                    case "toolCall":
                        if let tc = toolCallMap[segment.value] {
                            ToolCallView(toolCall: ToolCallDisplayData(from: tc))
                        }
                    default:
                        EmptyView()
                    }
                }
            } else {
                // Legacy layout: tool calls first, then content
                if !toolCalls.isEmpty {
                    ForEach(toolCalls.map(ToolCallDisplayData.init(from:))) { tc in
                        ToolCallView(toolCall: tc)
                    }
                }

                if !message.content.isEmpty {
                    Text(MarkdownRenderer.renderFull(message.content))
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Color(.controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
            }

            // Metadata row: timestamp + token usage
            if isHovering {
                HStack(spacing: 8) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let input = message.inputTokens {
                        tokenBadge("In: \(input)")
                        if let output = message.outputTokens {
                            tokenBadge("Out: \(output)")
                        }
                        if let reasoning = message.reasoningTokens, reasoning > 0 {
                            tokenBadge("Think: \(reasoning)")
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 60)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func tokenBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.fill.tertiary, in: Capsule())
    }

    // MARK: - System Message

    private var systemBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .italic()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Tool Message

    private var toolBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = message.toolName {
                Label(name, systemImage: "wrench.and.screwdriver")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(String(message.content.prefix(200)))
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.trailing, 60)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

#Preview("All Roles") {
    @Previewable @State var container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    let systemMsg: ChatMessageRecord = {
        let m = ChatMessageRecord(role: .system, content: "You are a helpful assistant.")
        container.mainContext.insert(m)
        return m
    }()

    let toolMsg: ChatMessageRecord = {
        let m = ChatMessageRecord(
            role: .tool,
            content: "{\"result\": \"success\", \"files\": 3}",
            toolCallId: "call_123",
            toolName: "search_files"
        )
        container.mainContext.insert(m)
        return m
    }()

    ScrollView {
        VStack(alignment: .leading, spacing: 4) {
            MessageBubble(message: data.userMessage)
            MessageBubble(message: data.assistantMessage)
            MessageBubble(message: systemMsg)
            MessageBubble(message: toolMsg)
        }
        .padding(.vertical)
    }
    .frame(width: 550, height: 600)
    .modelContainer(container)
}

import SwiftUI
import SwiftData

struct MessageBubble: View {
    let message: ChatMessageRecord

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
        HStack {
            Spacer(minLength: 60)
            Text(message.content)
                .textSelection(.enabled)
                .padding(12)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Assistant Message

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reasoning (collapsible)
            if let reasoning = message.reasoning, !reasoning.isEmpty {
                ReasoningView(reasoning: reasoning, isStreaming: false)
            }

            // Content
            if !message.content.isEmpty {
                Text(MarkdownRenderer.renderFull(message.content))
                    .textSelection(.enabled)
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Token usage
            if let input = message.inputTokens {
                HStack(spacing: 8) {
                    tokenBadge("In: \(input)")
                    if let output = message.outputTokens {
                        tokenBadge("Out: \(output)")
                    }
                    if let reasoning = message.reasoningTokens, reasoning > 0 {
                        tokenBadge("Think: \(reasoning)")
                    }
                }
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
        HStack {
            Image(systemName: "gearshape")
                .foregroundStyle(.secondary)
            Text(message.content)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Tool Message

    private var toolBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = message.toolName {
                Label(name, systemImage: "wrench")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(String(message.content.prefix(200)))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("User").font(.caption).foregroundStyle(.tertiary)
            MessageBubble(message: data.userMessage)

            Text("Assistant (with reasoning + tokens)").font(.caption).foregroundStyle(.tertiary)
            MessageBubble(message: data.assistantMessage)

            Text("System").font(.caption).foregroundStyle(.tertiary)
            MessageBubble(message: systemMsg)

            Text("Tool").font(.caption).foregroundStyle(.tertiary)
            MessageBubble(message: toolMsg)
        }
        .padding()
    }
    .frame(width: 500, height: 600)
    .modelContainer(container)
}

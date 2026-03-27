import SwiftUI
import SwiftData
import AgentRunKit

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Environment(ChatService.self) private var chatService
    @Environment(MCPService.self) private var mcpService

    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    let session: ChatSession

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private var isStreamingThisSession: Bool {
        chatService.isStreaming && chatService.streamingSessionID == session.id
    }

    var body: some View {
        messageList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .navigationTitle(session.title)
            .navigationSubtitle(modelSubtitle)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Date header for first message
                    if let first = session.sortedMessages.first {
                        dateHeader(for: first.timestamp)
                    }

                    ForEach(session.sortedMessages) { message in
                        MessageBubble(
                            message: message,
                            onResubmit: message.role == .user ? {
                                resubmitMessage(message)
                            } : nil
                        )
                        .id(message.id)
                    }

                    // Streaming content
                    if isStreamingThisSession {
                        streamingBubble
                    }

                    // Tool permission prompt
                    if let approval = chatService.pendingApproval,
                       isStreamingThisSession {
                        toolApprovalView(approval)
                            .padding(.horizontal, 16)
                            .id("approval")
                    }

                    // Error display
                    if let error = chatService.streamingError,
                       chatService.errorSessionID == session.id {
                        errorView(error)
                            .padding(.horizontal, 16)
                            .id("error")
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: session.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.streamingContent) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.streamingError) {
                if chatService.streamingError != nil {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    private func dateHeader(for date: Date) -> some View {
        Text(date, format: .dateTime.month(.wide).day().year())
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Streaming Content

    @ViewBuilder
    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Tool calls
            ForEach(chatService.activeToolCalls.map(ToolCallDisplayData.init(from:))) { toolCall in
                ToolCallView(toolCall: toolCall)
                    .padding(.horizontal, 16)
            }

            // Reasoning
            if !chatService.streamingReasoning.isEmpty {
                ReasoningView(reasoning: chatService.streamingReasoning, isStreaming: true)
                    .padding(.horizontal, 16)
            }

            // Content
            if !chatService.streamingContent.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(MarkdownRenderer.renderFull(chatService.streamingContent))
                        .textSelection(.enabled)
                    if isStreamingThisSession {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Color(.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .padding(.trailing, 60)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isStreamingThisSession && chatService.activeToolCalls.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Thinking...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Color(.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .padding(.horizontal, 16)
            }
        }
        .id("streaming")
    }

    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .imageScale(.small)
            Text(error)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .textSelection(.enabled)
            Spacer()
            Button {
                chatService.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help("Dismiss error")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toolApprovalView(_ approval: ChatService.PendingToolApproval) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Tool Permission Required")
                    .font(.callout.weight(.semibold))
            }

            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(approval.name)
                    .font(.callout.monospaced())
            }

            if !approval.arguments.isEmpty {
                if let jsonValue = JSONValue.parse(approval.arguments) {
                    StructuredContentView(jsonValue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(approval.arguments)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Deny") {
                    chatService.denyToolCall()
                }
                .keyboardShortcut(.cancelAction)

                Button("Allow") {
                    chatService.approveToolCall()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }



    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chatService.pendingApproval != nil, isStreamingThisSession {
                proxy.scrollTo("approval", anchor: .bottom)
            } else if chatService.streamingError != nil, chatService.errorSessionID == session.id {
                proxy.scrollTo("error", anchor: .bottom)
            } else if isStreamingThisSession {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = session.sortedMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        GlassEffectContainer {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...12)
                    .focused($isInputFocused)
                    .font(.body)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)

                if isStreamingThisSession {
                    Button {
                        chatService.stopStreaming()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .glassEffect(in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary
                                    : Color.accentColor
                            )
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .glassEffect(in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Send message (Return)")
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        let tools = mcpService.tools(
            for: session,
            allConfigs: mcpServerConfigs,
            onApprovalNeeded: { [chatService] name, args, desc in
                await chatService.requestApproval(toolName: name, arguments: args, description: desc)
            }
        )

        chatService.sendMessage(
            text,
            in: session,
            modelContext: modelContext,
            providerService: providerService,
            profiles: profiles,
            mcpTools: tools
        )
    }

    private func resubmitMessage(_ message: ChatMessageRecord) {
        let tools = mcpService.tools(
            for: session,
            allConfigs: mcpServerConfigs,
            onApprovalNeeded: { [chatService] name, args, desc in
                await chatService.requestApproval(toolName: name, arguments: args, description: desc)
            }
        )

        chatService.resubmitMessage(
            message,
            in: session,
            modelContext: modelContext,
            providerService: providerService,
            profiles: profiles,
            mcpTools: tools
        )
    }

    private var modelSubtitle: String {
        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let model = providerService.resolvedModel(for: session, profiles: profiles)
        return "\(profile?.name ?? "No Provider") \u{00B7} \(model)"
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        ChatView(session: data.session)
    }
    .previewEnvironment(container: container)
    .frame(width: 700, height: 500)
}

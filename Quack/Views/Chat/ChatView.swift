import SwiftUI
import SwiftData
import AgentRunKit

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProviderService.self) private var providerService
    @Environment(ChatService.self) private var chatService
    @Environment(MCPService.self) private var mcpService

    @Query(sort: \Provider.sortOrder) private var providers: [Provider]
    @Query private var mcpServerConfigs: [MCPServerConfig]

    let session: ChatSession

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private var isStreamingThisSession: Bool {
        chatService.isStreaming && chatService.streamingSessionID == session.id
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputArea
        }
        .navigationTitle(session.title)
        .navigationSubtitle(modelSubtitle)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.sortedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Streaming content
                    if isStreamingThisSession {
                        streamingBubble
                    }

                    // Error display
                    if let error = chatService.streamingError,
                       chatService.streamingSessionID == session.id {
                        errorView(error)
                    }
                }
                .padding()
            }
            .onChange(of: session.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatService.streamingContent) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool calls
            ForEach(chatService.activeToolCalls) { toolCall in
                ToolCallView(toolCall: toolCall)
            }

            // Reasoning
            if !chatService.streamingReasoning.isEmpty {
                ReasoningView(reasoning: chatService.streamingReasoning, isStreaming: true)
            }

            // Content
            if !chatService.streamingContent.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(MarkdownRenderer.renderFull(chatService.streamingContent))
                        .textSelection(.enabled)
                    if isStreamingThisSession {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    }
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isStreamingThisSession && chatService.activeToolCalls.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Thinking...")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .id("streaming")
    }

    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
        .padding(12)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isStreamingThisSession {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = session.sortedMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...10)
                .focused($isInputFocused)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        sendMessage()
                    }
                }

            if isStreamingThisSession {
                Button {
                    chatService.stopStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generating")
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message (Return)")
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(12)
        .background(.bar)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        let tools = mcpService.tools(for: session, allConfigs: mcpServerConfigs)

        chatService.sendMessage(
            text,
            in: session,
            modelContext: modelContext,
            providerService: providerService,
            providers: providers,
            mcpTools: tools
        )
    }

    private var modelSubtitle: String {
        let provider = providerService.resolvedProvider(for: session, providers: providers)
        let model = providerService.resolvedModel(for: session, providers: providers)
        return "\(provider?.name ?? "No Provider") - \(model)"
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

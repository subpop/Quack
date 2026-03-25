import Foundation
import SwiftData
import SwiftUI
import AgentRunKit

@Observable
@MainActor
final class ChatService {
    // MARK: - Streaming State

    var streamingContent: String = ""
    var streamingReasoning: String = ""
    var isStreaming: Bool = false
    var streamingError: String?
    var activeToolCalls: [ActiveToolCall] = []
    var streamingSessionID: UUID?

    private var streamTask: Task<Void, Never>?

    struct ActiveToolCall: Identifiable, Sendable {
        let id: String
        let name: String
        var state: State

        enum State: Sendable {
            case running
            case completed(String)
            case failed(String)
        }
    }

    // MARK: - Send Message

    func sendMessage(
        _ text: String,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: ProviderService,
        providers: [Provider],
        mcpTools: [any AnyTool<EmptyContext>]
    ) {
        // Cancel any existing stream
        stopStreaming()

        // Create and persist user message
        let userRecord = ChatMessageRecord(role: .user, content: text)
        userRecord.session = session
        session.messages.append(userRecord)
        session.updatedAt = Date()
        try? modelContext.save()

        // Auto-generate title from first message
        if session.messages.count == 1 {
            session.title = String(text.prefix(50))
            if text.count > 50 { session.title += "..." }
        }

        // Build the client
        guard let client = providerService.makeClient(
            for: session,
            providers: providers
        ) else {
            streamingError = "No provider configured. Set up a provider in Settings."
            return
        }

        // Convert history to AgentRunKit messages
        let history = MessageConverter.toChatMessages(session.sortedMessages)

        // Resolve session parameters
        let systemPrompt = session.systemPrompt
        let temperature = session.temperature

        // Build request context for temperature override
        var extraFields: [String: JSONValue] = [:]
        if let temperature {
            extraFields["temperature"] = .double(temperature)
        }
        let requestContext = extraFields.isEmpty ? nil : RequestContext(extraFields: extraFields)

        // Reset streaming state
        streamingContent = ""
        streamingReasoning = ""
        streamingError = nil
        activeToolCalls = []
        isStreaming = true
        streamingSessionID = session.id

        // Create Chat instance and stream
        let chat = Chat<EmptyContext>(
            client: client,
            tools: mcpTools,
            systemPrompt: systemPrompt
        )

        let sessionID = session.id

        streamTask = Task { [weak self] in
            do {
                for try await event in chat.stream(
                    history.last?.isUser == true ? text : text,
                    history: Array(history.dropLast()),
                    context: EmptyContext(),
                    requestContext: requestContext
                ) {
                    guard !Task.isCancelled else { break }
                    self?.handleStreamEvent(event, sessionID: sessionID)
                }
            } catch {
                await MainActor.run {
                    self?.streamingError = error.localizedDescription
                }
            }

            // Finalize: persist the assistant message
            await MainActor.run {
                self?.finalizeStream(sessionID: sessionID, modelContext: modelContext)
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingSessionID = nil
    }

    func regenerateLastResponse(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: ProviderService,
        providers: [Provider],
        mcpTools: [any AnyTool<EmptyContext>]
    ) {
        // Remove the last assistant message
        let sorted = session.sortedMessages
        if let last = sorted.last, last.role == .assistant {
            modelContext.delete(last)
            session.messages.removeAll { $0.id == last.id }
        }

        // Re-send the last user message
        if let lastUser = session.sortedMessages.last(where: { $0.role == .user }) {
            sendMessage(
                lastUser.content,
                in: session,
                modelContext: modelContext,
                providerService: providerService,
                providers: providers,
                mcpTools: mcpTools
            )
        }
    }

    // MARK: - Private

    private func handleStreamEvent(_ event: StreamEvent, sessionID: UUID) {
        switch event {
        case .delta(let text):
            streamingContent += text

        case .reasoningDelta(let text):
            streamingReasoning += text

        case .toolCallStarted(let name, let id):
            activeToolCalls.append(ActiveToolCall(id: id, name: name, state: .running))

        case .toolCallCompleted(let id, _, let result):
            if let index = activeToolCalls.firstIndex(where: { $0.id == id }) {
                activeToolCalls[index].state = result.isError
                    ? .failed(result.content)
                    : .completed(result.content)
            }

        case .finished(let tokenUsage, _, _, _):
            _ = tokenUsage // Token usage is captured via the accumulated content

        default:
            break
        }
    }

    private func finalizeStream(sessionID: UUID, modelContext: ModelContext) {
        guard !streamingContent.isEmpty || !streamingReasoning.isEmpty else {
            isStreaming = false
            streamingSessionID = nil
            return
        }

        // Find the session
        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.id == sessionID }
        )
        guard let session = try? modelContext.fetch(descriptor).first else {
            isStreaming = false
            streamingSessionID = nil
            return
        }

        // Create assistant message record
        let record = ChatMessageRecord(
            role: .assistant,
            content: streamingContent,
            reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning
        )
        record.session = session
        session.messages.append(record)
        session.updatedAt = Date()
        try? modelContext.save()

        isStreaming = false
        streamingSessionID = nil
    }
}

private extension ChatMessage {
    var isUser: Bool {
        switch self {
        case .user: true
        default: false
        }
    }
}

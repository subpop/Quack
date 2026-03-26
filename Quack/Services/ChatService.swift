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

    /// Tracks which session an error belongs to, independently of streaming state.
    /// Unlike `streamingSessionID`, this is not cleared when streaming ends,
    /// allowing the error banner to persist until the user sends a new message.
    var errorSessionID: UUID?

    private var streamTask: Task<Void, Never>?

    struct ActiveToolCall: Identifiable, Sendable {
        let id: String
        let name: String
        var arguments: String?
        var state: State

        enum State: Sendable {
            case running
            case completed(String)
            case failed(String)
        }
    }

    /// Pending tool call that requires user permission before executing.
    struct PendingToolApproval: Identifiable, Sendable {
        let id: String
        let name: String
        let arguments: String
    }

    /// User's response to a tool permission prompt.
    var pendingApproval: PendingToolApproval?
    var approvalContinuation: CheckedContinuation<Bool, Never>?

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
            errorSessionID = session.id
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
        errorSessionID = nil
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
                    self?.errorSessionID = sessionID
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

    func dismissError() {
        streamingError = nil
        errorSessionID = nil
    }

    /// Called by the permission wrapper when a tool needs user approval.
    /// Suspends until the user approves or denies.
    func requestApproval(toolName: String, arguments: String, description: String) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.pendingApproval = PendingToolApproval(
                    id: UUID().uuidString,
                    name: toolName,
                    arguments: arguments
                )
                self.approvalContinuation = continuation
            }
        }
    }

    /// User approved the pending tool call.
    func approveToolCall() {
        approvalContinuation?.resume(returning: true)
        approvalContinuation = nil
        pendingApproval = nil
    }

    /// User denied the pending tool call.
    func denyToolCall() {
        approvalContinuation?.resume(returning: false)
        approvalContinuation = nil
        pendingApproval = nil
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

    /// Resubmit a specific user message: delete the assistant response immediately
    /// following it (and any associated tool messages), then re-send the user message
    /// to regenerate a fresh response.
    func resubmitMessage(
        _ message: ChatMessageRecord,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: ProviderService,
        providers: [Provider],
        mcpTools: [any AnyTool<EmptyContext>]
    ) {
        guard message.role == .user else { return }

        let sorted = session.sortedMessages
        guard let messageIndex = sorted.firstIndex(where: { $0.id == message.id }) else { return }

        // Collect all messages after this user message up to (but not including)
        // the next user message — these are the assistant/tool responses to remove.
        var messagesToDelete: [ChatMessageRecord] = []
        for i in (messageIndex + 1)..<sorted.count {
            let msg = sorted[i]
            if msg.role == .user { break }
            messagesToDelete.append(msg)
        }

        // Delete the response messages
        for msg in messagesToDelete {
            session.messages.removeAll { $0.id == msg.id }
            modelContext.delete(msg)
        }
        try? modelContext.save()

        // Re-send the user message content (without creating a duplicate user message)
        stopStreaming()

        let text = message.content

        guard let client = providerService.makeClient(
            for: session,
            providers: providers
        ) else {
            streamingError = "No provider configured. Set up a provider in Settings."
            errorSessionID = session.id
            return
        }

        // Build history up to and including the resubmitted user message
        let updatedSorted = session.sortedMessages
        let history = MessageConverter.toChatMessages(updatedSorted)

        let systemPrompt = session.systemPrompt
        let temperature = session.temperature

        var extraFields: [String: JSONValue] = [:]
        if let temperature {
            extraFields["temperature"] = .double(temperature)
        }
        let requestContext = extraFields.isEmpty ? nil : RequestContext(extraFields: extraFields)

        streamingContent = ""
        streamingReasoning = ""
        streamingError = nil
        errorSessionID = nil
        activeToolCalls = []
        isStreaming = true
        streamingSessionID = session.id

        let chat = Chat<EmptyContext>(
            client: client,
            tools: mcpTools,
            systemPrompt: systemPrompt
        )

        let sessionID = session.id

        streamTask = Task { [weak self] in
            do {
                for try await event in chat.stream(
                    text,
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
                    self?.errorSessionID = sessionID
                }
            }

            await MainActor.run {
                self?.finalizeStream(sessionID: sessionID, modelContext: modelContext)
            }
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

        case .finished(_, _, _, let history):
            // Extract tool call arguments from the finished history.
            // The history contains AssistantMessages with ToolCalls that have arguments.
            for message in history {
                if case .assistant(let assistantMsg) = message {
                    for toolCall in assistantMsg.toolCalls {
                        if let index = activeToolCalls.firstIndex(where: { $0.id == toolCall.id }) {
                            activeToolCalls[index].arguments = toolCall.arguments
                        }
                    }
                }
            }

        default:
            break
        }
    }

    private func finalizeStream(sessionID: UUID, modelContext: ModelContext) {
        guard !streamingContent.isEmpty || !streamingReasoning.isEmpty || !activeToolCalls.isEmpty else {
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

        // Encode completed tool calls (with arguments + results) for persistence
        let toolCallsJSON = Self.encodeCompletedToolCalls(activeToolCalls)

        // Create assistant message record
        let record = ChatMessageRecord(
            role: .assistant,
            content: streamingContent,
            reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning,
            toolCallsJSON: toolCallsJSON
        )
        record.session = session
        session.messages.append(record)
        session.updatedAt = Date()
        try? modelContext.save()

        isStreaming = false
        streamingSessionID = nil
    }

    // MARK: - Tool Call Serialization

    /// Serializable representation of a completed tool call with arguments and result.
    struct CompletedToolCallData: Codable {
        let id: String
        let name: String
        let arguments: String?
        let result: String?
        let isError: Bool
    }

    static func encodeCompletedToolCalls(_ toolCalls: [ActiveToolCall]) -> String? {
        let completed = toolCalls.compactMap { call -> CompletedToolCallData? in
            switch call.state {
            case .completed(let result):
                return CompletedToolCallData(
                    id: call.id, name: call.name,
                    arguments: call.arguments, result: result, isError: false
                )
            case .failed(let error):
                return CompletedToolCallData(
                    id: call.id, name: call.name,
                    arguments: call.arguments, result: error, isError: true
                )
            case .running:
                return nil
            }
        }
        guard !completed.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(completed),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    static func decodeCompletedToolCalls(from json: String?) -> [CompletedToolCallData] {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let calls = try? JSONDecoder().decode([CompletedToolCallData].self, from: data)
        else { return [] }
        return calls
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

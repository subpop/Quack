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

    /// Ordered segments representing the interleaved sequence of text and tool
    /// calls as they arrive during streaming.
    var streamingSegments: [StreamingSegment] = []

    /// A segment of streaming content — either accumulated text or a reference
    /// to a tool call (looked up by id in `activeToolCalls`).
    enum StreamingSegment {
        case text(String)
        case toolCall(id: String)
    }

    /// Tracks which session an error belongs to, independently of streaming state.
    /// Unlike `streamingSessionID`, this is not cleared when streaming ends,
    /// allowing the error banner to persist until the user sends a new message.
    var errorSessionID: UUID?

    private var streamTask: Task<Void, Never>?
    private var streamedInputTokens: Int?
    private var streamedOutputTokens: Int?
    private var streamedReasoningTokens: Int?
    /// The complete message history returned by the `.finished` event.
    /// Used during finalization to persist intermediate assistant/tool messages.
    private var finishedHistory: [ChatMessage]?

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
        profiles: [ProviderProfile],
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

        // Auto-generate title from first message using on-device Foundation Model
        if session.messages.count == 1 {
            let sessionID = session.id
            let messageText = text
            Task { @MainActor in
                let title = await TitleGenerationService.generateTitle(for: messageText)
                // Re-fetch session to avoid stale reference
                let descriptor = FetchDescriptor<ChatSession>(
                    predicate: #Predicate { $0.id == sessionID }
                )
                if let session = try? modelContext.fetch(descriptor).first {
                    session.title = title
                    try? modelContext.save()
                }
            }
        }

        // Build the client
        guard let client = providerService.makeClient(
            for: session,
            profiles: profiles
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
        streamingSegments = []
        streamedInputTokens = nil
        streamedOutputTokens = nil
        streamedReasoningTokens = nil
        finishedHistory = nil
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
        profiles: [ProviderProfile],
        mcpTools: [any AnyTool<EmptyContext>]
    ) {
        // Remove all assistant and tool messages after the last user message.
        // With multi-turn tool loops, there may be multiple assistant + tool
        // messages forming a single response.
        let sorted = session.sortedMessages
        if let lastUserIndex = sorted.lastIndex(where: { $0.role == .user }) {
            let messagesToDelete = sorted.suffix(from: sorted.index(after: lastUserIndex))
            for msg in messagesToDelete {
                session.messages.removeAll { $0.id == msg.id }
                modelContext.delete(msg)
            }
        }

        // Re-send the last user message
        if let lastUser = session.sortedMessages.last(where: { $0.role == .user }) {
            sendMessage(
                lastUser.content,
                in: session,
                modelContext: modelContext,
                providerService: providerService,
                profiles: profiles,
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
        profiles: [ProviderProfile],
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
            profiles: profiles
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
        streamingSegments = []
        streamedInputTokens = nil
        streamedOutputTokens = nil
        streamedReasoningTokens = nil
        finishedHistory = nil
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
            // Append to the current text segment, or create one if the last
            // segment is a tool call (or there are no segments yet).
            if case .text(let existing) = streamingSegments.last {
                streamingSegments[streamingSegments.count - 1] = .text(existing + text)
            } else {
                streamingSegments.append(.text(text))
            }

        case .reasoningDelta(let text):
            streamingReasoning += text

        case .toolCallStarted(let name, let id):
            activeToolCalls.append(ActiveToolCall(id: id, name: name, state: .running))
            streamingSegments.append(.toolCall(id: id))

        case .toolCallCompleted(let id, _, let result):
            if let index = activeToolCalls.firstIndex(where: { $0.id == id }) {
                activeToolCalls[index].state = result.isError
                    ? .failed(result.content)
                    : .completed(result.content)
            }

        case .finished(let usage, _, _, let history):
            streamedInputTokens = usage.input
            streamedOutputTokens = usage.output
            streamedReasoningTokens = usage.reasoning
            finishedHistory = history
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

        // Use the finished history to persist all messages from this streaming
        // session. The history contains the full conversation including the
        // original messages; we only need the new ones (everything after the
        // last user message).
        if let history = finishedHistory {
            persistFromHistory(
                history,
                session: session,
                modelContext: modelContext
            )
        } else {
            // Fallback: no history available (e.g. stream was cancelled before
            // finishing). Persist what we have as a single assistant message.
            let toolCallsJSON = Self.encodeCompletedToolCalls(activeToolCalls)
            let contentSegmentsJSON = Self.encodeContentSegments(streamingSegments)
            let record = ChatMessageRecord(
                role: .assistant,
                content: streamingContent,
                reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning,
                inputTokens: streamedInputTokens,
                outputTokens: streamedOutputTokens,
                reasoningTokens: streamedReasoningTokens,
                toolCallsJSON: toolCallsJSON,
                contentSegmentsJSON: contentSegmentsJSON
            )
            record.session = session
            session.messages.append(record)
        }

        session.updatedAt = Date()
        try? modelContext.save()

        isStreaming = false
        streamingSessionID = nil
    }

    /// Persist new messages from the finished history into the session.
    ///
    /// The history from AgentRunKit contains the full conversation thread:
    /// `[.system, ...prior history..., .user, .assistant(toolCalls), .tool, ..., .assistant(final)]`
    ///
    /// We extract only the new messages produced during this streaming session
    /// (everything after the last `.user` message) and create `ChatMessageRecord`
    /// objects for each. This ensures that assistant messages with `tool_use` blocks
    /// are always followed by corresponding `tool_result` messages, which the
    /// Anthropic API requires.
    private func persistFromHistory(
        _ history: [ChatMessage],
        session: ChatSession,
        modelContext: ModelContext
    ) {
        // Find the index of the last user message — everything after it is new
        guard let lastUserIndex = history.lastIndex(where: { msg in
            if case .user = msg { return true }
            if case .userMultimodal = msg { return true }
            return false
        }) else { return }

        let newMessages = Array(history[(lastUserIndex + 1)...])
        guard !newMessages.isEmpty else { return }

        // Build a lookup of active tool calls by id for result/argument data
        let activeToolCallMap = Dictionary(
            uniqueKeysWithValues: activeToolCalls.map { ($0.id, $0) }
        )

        // Track which assistant message index we're on to assign streaming
        // metadata (segments, tokens, reasoning) to the correct one.
        // The final assistant message (the one with no tool calls) gets the
        // accumulated streaming content, reasoning, and token counts.
        // Intermediate assistant messages get their tool calls from the history.
        let lastAssistantIndex = newMessages.lastIndex(where: { msg in
            if case .assistant = msg { return true }
            return false
        })

        for (offset, message) in newMessages.enumerated() {
            let record: ChatMessageRecord
            let isLastAssistant = offset == lastAssistantIndex

            switch message {
            case .assistant(let assistantMsg):
                if isLastAssistant {
                    // Final assistant message: use the streamed content, reasoning,
                    // and token usage. Also include tool calls if any (rare for
                    // the final message but possible).
                    let toolCalls = assistantMsg.toolCalls
                    let toolCallsForRecord: [ActiveToolCall] = toolCalls.map { tc in
                        activeToolCallMap[tc.id] ?? ActiveToolCall(
                            id: tc.id, name: tc.name, arguments: tc.arguments,
                            state: .completed("")
                        )
                    }
                    let toolCallsJSON = Self.encodeCompletedToolCalls(toolCallsForRecord)
                    let contentSegmentsJSON = Self.encodeContentSegments(streamingSegments)

                    record = ChatMessageRecord(
                        role: .assistant,
                        content: streamingContent,
                        reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning,
                        inputTokens: streamedInputTokens,
                        outputTokens: streamedOutputTokens,
                        reasoningTokens: streamedReasoningTokens,
                        toolCallsJSON: toolCallsJSON,
                        contentSegmentsJSON: contentSegmentsJSON
                    )
                } else {
                    // Intermediate assistant message: has tool calls but
                    // typically empty or minimal text content.
                    let toolCalls = assistantMsg.toolCalls
                    let toolCallsForRecord: [ActiveToolCall] = toolCalls.map { tc in
                        activeToolCallMap[tc.id] ?? ActiveToolCall(
                            id: tc.id, name: tc.name, arguments: tc.arguments,
                            state: .completed("")
                        )
                    }
                    let toolCallsJSON = Self.encodeCompletedToolCalls(toolCallsForRecord)

                    // Build segments for this intermediate message
                    var intermediateSegments: [StreamingSegment] = []
                    if !assistantMsg.content.isEmpty {
                        intermediateSegments.append(.text(assistantMsg.content))
                    }
                    for tc in toolCalls {
                        intermediateSegments.append(.toolCall(id: tc.id))
                    }
                    let segmentsJSON = Self.encodeContentSegments(intermediateSegments)

                    record = ChatMessageRecord(
                        role: .assistant,
                        content: assistantMsg.content,
                        reasoning: assistantMsg.reasoning?.content,
                        toolCallsJSON: toolCallsJSON,
                        contentSegmentsJSON: segmentsJSON
                    )
                }

            case .tool(let id, let name, let content):
                record = ChatMessageRecord(
                    role: .tool,
                    content: content,
                    toolCallId: id,
                    toolName: name
                )

            default:
                // Skip system/user messages — they're already persisted
                continue
            }

            record.session = session
            session.messages.append(record)
        }
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

    // MARK: - Content Segment Serialization

    /// Serializable representation of a content segment for persistence.
    struct ContentSegmentData: Codable {
        let type: String   // "text" or "toolCall"
        let value: String  // text content or tool call id
    }

    static func encodeContentSegments(_ segments: [StreamingSegment]) -> String? {
        let data = segments.compactMap { segment -> ContentSegmentData? in
            switch segment {
            case .text(let text):
                guard !text.isEmpty else { return nil }
                return ContentSegmentData(type: "text", value: text)
            case .toolCall(let id):
                return ContentSegmentData(type: "toolCall", value: id)
            }
        }
        guard !data.isEmpty else { return nil }
        guard let jsonData = try? JSONEncoder().encode(data),
              let json = String(data: jsonData, encoding: .utf8)
        else { return nil }
        return json
    }

    static func decodeContentSegments(from json: String?) -> [ContentSegmentData] {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let segments = try? JSONDecoder().decode([ContentSegmentData].self, from: data)
        else { return [] }
        return segments
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

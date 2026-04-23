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
import os
import SwiftData
import Observation
import AgentRunKit
import QuackInterface

@Observable
@MainActor
public final class ChatService: ChatServiceProtocol {
    // MARK: - Streaming State

    public var streamingContent: String = ""
    public var streamingReasoning: String = ""
    public var isStreaming: Bool = false
    public var streamingError: String?
    public var activeToolCalls: [ActiveToolCall] = []
    public var streamingSessionID: UUID?

    /// Ordered segments representing the interleaved sequence of text and tool
    /// calls as they arrive during streaming.
    public var streamingSegments: [StreamingSegment] = []

    /// Tracks which session an error belongs to, independently of streaming state.
    /// Unlike `streamingSessionID`, this is not cleared when streaming ends,
    /// allowing the error banner to persist until the user sends a new message.
    public var errorSessionID: UUID?

    private var streamTask: Task<Void, Never>?
    private var streamedInputTokens: Int?
    private var streamedOutputTokens: Int?
    private var streamedReasoningTokens: Int?

    /// Signposter for measuring streaming markdown rendering performance.
    private static let signposter = OSSignposter(
        subsystem: "app.subpop.Quack",
        category: .pointsOfInterest
    )

    /// Active signpost interval state for the current streaming session.
    private var streamIntervalState: OSSignpostIntervalState?
    /// The complete message history returned by the `.finished` event.
    /// Used during finalization to persist intermediate assistant/tool messages.
    private var finishedHistory: [ChatMessage]?

    /// User's response to a tool permission prompt.
    public var pendingApproval: PendingToolApproval?
    public var approvalContinuation: CheckedContinuation<Bool, Never>?

    /// Optional notification service for alerting the user when a tool approval
    /// is pending and the app is not frontmost.
    /// Set this to a NotificationService instance from the app layer.
    public var notificationService: AnyObject?

    /// Optional closure that generates a short title from a user message.
    /// Set this from the app layer to use on-device Foundation Models.
    /// Falls back to simple truncation when not set.
    public var titleGenerator: (@MainActor @Sendable (String) async -> String)?

    /// Optional skill service for composing skills into the system prompt.
    /// Set this from the app layer after creating the SkillService.
    public var skillService: (any SkillServiceProtocol)?

    // MARK: - Init

    public init() {}

    // MARK: - Send Message

    public func sendMessage(
        _ text: String,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
    ) {
        guard let providerService = providerService as? ProviderService else { return }

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
                let title: String
                if let generator = self.titleGenerator {
                    title = await generator(messageText)
                } else {
                    // Simple fallback: truncate to 50 characters
                    var t = String(messageText.prefix(50))
                    if messageText.count > 50 { t += "..." }
                    title = t
                }
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

        // Reset streaming state early so UI reflects loading
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

        let sessionID = session.id

        streamTask = Task { [weak self] in
            do {
                // Pre-load MLX model if needed (no-op for other providers).
                // This must happen inside the Task so it can be async and
                // show loading progress in the UI.
                try await providerService.prepareMLXModel(
                    for: session,
                    profiles: profiles
                )
            } catch {
                await MainActor.run {
                    self?.streamingError = "Failed to load MLX model: \(error.localizedDescription)"
                    self?.errorSessionID = sessionID
                    self?.isStreaming = false
                    self?.streamingSessionID = nil
                }
                return
            }

            // Build the client (synchronous — MLX container is now cached)
            guard let client = providerService.makeClient(
                for: session,
                profiles: profiles
            ) else {
                await MainActor.run {
                    self?.streamingError = "No provider configured. Set up a provider in Settings."
                    self?.errorSessionID = sessionID
                    self?.isStreaming = false
                    self?.streamingSessionID = nil
                }
                return
            }

            // Convert history to AgentRunKit messages
            let history = MessageConverter.toChatMessages(session.sortedMessages)

            // Resolve session parameters — compose skill catalog into the system prompt
            let basePrompt = session.systemPrompt
            let alwaysEnabled = session.alwaysEnabledSkillNames ?? []
            var systemPrompt = self?.skillService?.composedSystemPrompt(
                basePrompt: basePrompt,
                alwaysEnabledSkillNames: alwaysEnabled
            ) ?? basePrompt

            // Inject working directory context into the system prompt
            if let workDir = session.workingDirectory {
                let directive = "\n\nYour current working directory is: \(workDir)\nWhen using file tools or running commands, use this as the base directory unless the user specifies otherwise. Relative paths are resolved against this directory."
                systemPrompt = (systemPrompt ?? "") + directive
            }

            let temperature = session.temperature

            // Build request context for temperature override
            var extraFields: [String: JSONValue] = [:]
            if let temperature {
                extraFields["temperature"] = .double(temperature)
            }
            let requestContext = extraFields.isEmpty ? nil : RequestContext(extraFields: extraFields)

            // Resolve max tool rounds (default 10 matches AgentRunKit)
            let maxToolRounds = session.maxToolRounds ?? 10

            // Create Chat instance and stream
            let toolContext = QuackToolContext(workingDirectory: session.workingDirectory)
            let chat = Chat<QuackToolContext>(
                client: client,
                tools: tools,
                systemPrompt: systemPrompt,
                maxToolRounds: maxToolRounds
            )

            do {
                for try await event in chat.stream(
                    history.last?.isUser == true ? text : text,
                    history: Array(history.dropLast()),
                    context: toolContext,
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

    public func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingSessionID = nil
    }

    public func dismissError() {
        streamingError = nil
        errorSessionID = nil
    }

    /// Called by the permission wrapper when a tool needs user approval.
    /// Suspends until the user approves or denies.
    public func requestApproval(toolName: String, arguments: String, description: String) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.pendingApproval = PendingToolApproval(
                    id: UUID().uuidString,
                    name: toolName,
                    arguments: arguments
                )
                self.approvalContinuation = continuation
                if let ns = self.notificationService {
                    // Call showToolApprovalNotification if available via NotificationService
                    (ns as? any NotificationServiceProtocol)?.showToolApprovalNotification(toolName: toolName)
                }
            }
        }
    }

    /// User approved the pending tool call.
    public func approveToolCall() {
        approvalContinuation?.resume(returning: true)
        approvalContinuation = nil
        pendingApproval = nil
        if let ns = notificationService as? any NotificationServiceProtocol {
            ns.clearToolApprovalNotification()
        }
    }

    /// User denied the pending tool call.
    public func denyToolCall() {
        approvalContinuation?.resume(returning: false)
        approvalContinuation = nil
        pendingApproval = nil
        if let ns = notificationService as? any NotificationServiceProtocol {
            ns.clearToolApprovalNotification()
        }
    }

    public func regenerateLastResponse(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
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
                tools: tools
            )
        }
    }

    /// Resubmit a specific user message: delete the assistant response immediately
    /// following it (and any associated tool messages), then re-send the user message
    /// to regenerate a fresh response.
    public func resubmitMessage(
        _ message: ChatMessageRecord,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
    ) {
        guard let providerService = providerService as? ProviderService else { return }
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

        let sessionID = session.id

        streamTask = Task { [weak self] in
            do {
                // Pre-load MLX model if needed
                try await providerService.prepareMLXModel(
                    for: session,
                    profiles: profiles
                )
            } catch {
                await MainActor.run {
                    self?.streamingError = "Failed to load MLX model: \(error.localizedDescription)"
                    self?.errorSessionID = sessionID
                    self?.isStreaming = false
                    self?.streamingSessionID = nil
                }
                return
            }

            guard let client = providerService.makeClient(
                for: session,
                profiles: profiles
            ) else {
                await MainActor.run {
                    self?.streamingError = "No provider configured. Set up a provider in Settings."
                    self?.errorSessionID = sessionID
                    self?.isStreaming = false
                    self?.streamingSessionID = nil
                }
                return
            }

            // Build history up to and including the resubmitted user message
            let updatedSorted = session.sortedMessages
            let history = MessageConverter.toChatMessages(updatedSorted)

            // Compose skill catalog into the system prompt
            let basePrompt = session.systemPrompt
            let alwaysEnabled = session.alwaysEnabledSkillNames ?? []
            var systemPrompt = self?.skillService?.composedSystemPrompt(
                basePrompt: basePrompt,
                alwaysEnabledSkillNames: alwaysEnabled
            ) ?? basePrompt

            // Inject working directory context into the system prompt
            if let workDir = session.workingDirectory {
                let directive = "\n\nYour current working directory is: \(workDir)\nWhen using file tools or running commands, use this as the base directory unless the user specifies otherwise. Relative paths are resolved against this directory."
                systemPrompt = (systemPrompt ?? "") + directive
            }

            let temperature = session.temperature

            var extraFields: [String: JSONValue] = [:]
            if let temperature {
                extraFields["temperature"] = .double(temperature)
            }
            let requestContext = extraFields.isEmpty ? nil : RequestContext(extraFields: extraFields)

            // Resolve max tool rounds (default 10 matches AgentRunKit)
            let maxToolRounds = session.maxToolRounds ?? 10

            let toolContext = QuackToolContext(workingDirectory: session.workingDirectory)
            let chat = Chat<QuackToolContext>(
                client: client,
                tools: tools,
                systemPrompt: systemPrompt,
                maxToolRounds: maxToolRounds
            )

            do {
                for try await event in chat.stream(
                    text,
                    history: Array(history.dropLast()),
                    context: toolContext,
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
        // Begin the stream interval on the first event if needed.
        if streamIntervalState == nil {
            streamIntervalState = Self.signposter.beginInterval(
                "streamSession",
                id: Self.signposter.makeSignpostID()
            )
        }

        switch event.kind {
        case .delta(let text):
            let totalChars = self.streamingContent.count + text.count
            Self.signposter.emitEvent("streamDelta", "\(text.count) chars, total \(totalChars)")
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
        // End the stream session signpost interval.
        if let state = streamIntervalState {
            let totalChars = self.streamingContent.count
            Self.signposter.endInterval("streamSession", state, "\(totalChars) chars total")
            streamIntervalState = nil
        }

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

            // Create tool result records for any completed tool calls so the
            // Anthropic API sees matching tool_result blocks for every tool_use.
            for toolCall in activeToolCalls {
                let resultContent: String
                switch toolCall.state {
                case .completed(let content):
                    resultContent = content
                case .failed(let content):
                    resultContent = content
                case .running:
                    resultContent = "Tool call was interrupted."
                }
                let toolRecord = ChatMessageRecord(
                    role: .tool,
                    content: resultContent,
                    toolCallId: toolCall.id,
                    toolName: toolCall.name
                )
                toolRecord.session = session
                session.messages.append(toolRecord)
            }
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

        var newMessages = Array(history[(lastUserIndex + 1)...])
        guard !newMessages.isEmpty else { return }

        // Ensure every tool_use in the last assistant message has a matching
        // tool result. During cancellation, the history may contain an
        // assistant message with tool calls where some or all tool results
        // are missing (tool execution was interrupted). We append synthetic
        // tool results for any that are missing.
        if case .assistant(let lastAssistant) = newMessages.last,
           !lastAssistant.toolCalls.isEmpty {
            let existingToolResultIds = Set(
                newMessages.compactMap { msg -> String? in
                    if case .tool(let id, _, _) = msg { return id }
                    return nil
                }
            )
            for tc in lastAssistant.toolCalls where !existingToolResultIds.contains(tc.id) {
                newMessages.append(.tool(id: tc.id, name: tc.name, content: "Tool call was interrupted."))
            }
        }

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

    public static func encodeCompletedToolCalls(_ toolCalls: [ActiveToolCall]) -> String? {
        let completed = toolCalls.map { call -> CompletedToolCallData in
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
                return CompletedToolCallData(
                    id: call.id, name: call.name,
                    arguments: call.arguments, result: "Tool call was interrupted.", isError: true
                )
            }
        }
        guard !completed.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(completed),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    // MARK: - Content Segment Serialization

    public static func encodeContentSegments(_ segments: [StreamingSegment]) -> String? {
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
}

/// Protocol for notification service injection from app layer.
public protocol NotificationServiceProtocol: AnyObject {
    func showToolApprovalNotification(toolName: String)
    func clearToolApprovalNotification()
}

private extension ChatMessage {
    var isUser: Bool {
        switch self {
        case .user: true
        default: false
        }
    }
}

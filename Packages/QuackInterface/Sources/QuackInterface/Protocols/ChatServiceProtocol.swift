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

// MARK: - Promoted Types

/// A segment of streaming content — either accumulated text or a reference
/// to a tool call (looked up by id in `activeToolCalls`).
public enum StreamingSegment: Sendable {
    case text(String)
    case toolCall(id: String)
}

/// Tracks an in-progress or completed tool call during streaming.
public struct ActiveToolCall: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var arguments: String?
    public var state: ActiveToolCallState
    /// A brief on-device generated summary of what the tool call did.
    /// Populated asynchronously after the tool call completes.
    public var summary: String?

    public init(id: String, name: String, arguments: String? = nil, state: ActiveToolCallState, summary: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.state = state
        self.summary = summary
    }
}

/// The state of an active tool call.
public enum ActiveToolCallState: Sendable {
    case running
    case pendingApproval(arguments: String, description: String)
    case denied(reason: String?)
    case completed(String)
    case failed(String)
}

/// Serializable representation of a completed tool call with arguments and result.
public struct CompletedToolCallData: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String?
    public let result: String?
    public let isError: Bool
    /// A brief on-device generated summary of what the tool call did.
    public let summary: String?

    public init(id: String, name: String, arguments: String?, result: String?, isError: Bool, summary: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.isError = isError
        self.summary = summary
    }
}

/// Serializable representation of a content segment for persistence.
public struct ContentSegmentData: Codable, Sendable {
    public let type: String   // "text" or "toolCall"
    public let value: String  // text content or tool call id

    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }
}

// MARK: - Free Functions (Decoding Helpers)

/// Decode completed tool calls from a JSON string.
public func decodeCompletedToolCalls(from json: String?) -> [CompletedToolCallData] {
    guard let json, !json.isEmpty,
          let data = json.data(using: .utf8),
          let calls = try? JSONDecoder().decode([CompletedToolCallData].self, from: data)
    else { return [] }
    return calls
}

/// Decode content segments from a JSON string.
public func decodeContentSegments(from json: String?) -> [ContentSegmentData] {
    guard let json, !json.isEmpty,
          let data = json.data(using: .utf8),
          let segments = try? JSONDecoder().decode([ContentSegmentData].self, from: data)
    else { return [] }
    return segments
}

// MARK: - Protocol

@MainActor
public protocol ChatServiceProtocol: AnyObject, Observable, Sendable {
    var isStreaming: Bool { get }
    var streamingContent: String { get }
    var streamingReasoning: String { get }
    var streamingError: String? { get }
    var streamingSessionID: UUID? { get }
    var errorSessionID: UUID? { get }
    var streamingSegments: [StreamingSegment] { get }
    var activeToolCalls: [ActiveToolCall] { get }

    /// The tool call ID that is currently awaiting user approval, if any.
    var pendingApprovalToolCallID: String? { get }

    func sendMessage(
        _ text: String,
        attachments: [Attachment],
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    )

    func resubmitMessage(
        _ message: ChatMessageRecord,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    )

    func regenerateLastResponse(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    )

    func stopStreaming()
    func dismissError()
    func approveToolCall(id: String)
    func denyToolCall(id: String)

    // MARK: - Context Management

    /// Manually compact the conversation by summarizing older messages.
    func compactConversation(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile]
    ) async
}

// MARK: - Environment Key

private struct ChatServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ChatServiceProtocol = PlaceholderChatService()
}

public extension EnvironmentValues {
    var chatService: any ChatServiceProtocol {
        get { self[ChatServiceKey.self] }
        set { self[ChatServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderChatService: ChatServiceProtocol {
    var isStreaming: Bool = false
    var streamingContent: String = ""
    var streamingReasoning: String = ""
    var streamingError: String? = nil
    var streamingSessionID: UUID? = nil
    var errorSessionID: UUID? = nil
    var streamingSegments: [StreamingSegment] = []
    var activeToolCalls: [ActiveToolCall] = []
    var pendingApprovalToolCallID: String? = nil

    func sendMessage(
        _ text: String,
        attachments: [Attachment],
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    ) {}

    func resubmitMessage(
        _ message: ChatMessageRecord,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    ) {}

    func regenerateLastResponse(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>],
        approvalPolicy: ToolApprovalPolicy
    ) {}

    func stopStreaming() {}
    func dismissError() {}
    func approveToolCall(id: String) {}
    func denyToolCall(id: String) {}

    func compactConversation(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile]
    ) async {}
}

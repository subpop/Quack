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
import Observation
import QuackInterface
import SwiftData
import AgentRunKit

/// A minimal no-op ``ChatServiceProtocol`` implementation for SwiftUI previews.
@Observable
@MainActor
final class PreviewChatService: ChatServiceProtocol {
    var isStreaming = false
    var streamingContent = ""
    var streamingReasoning = ""
    var streamingError: String? = nil
    var streamingSessionID: UUID? = nil
    var errorSessionID: UUID? = nil
    var streamingSegments: [StreamingSegment] = []
    var activeToolCalls: [ActiveToolCall] = []
    var pendingApproval: PendingToolApproval? = nil

    func sendMessage(
        _ text: String,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
    ) {}

    func resubmitMessage(
        _ message: ChatMessageRecord,
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
    ) {}

    func regenerateLastResponse(
        in session: ChatSession,
        modelContext: ModelContext,
        providerService: any ProviderServiceProtocol,
        profiles: [ProviderProfile],
        tools: [any AnyTool<QuackToolContext>]
    ) {}

    func stopStreaming() {}
    func dismissError() {}
    func approveToolCall() {}
    func denyToolCall() {}
    func requestApproval(toolName: String, arguments: String, description: String) async -> Bool { false }
}

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

import Testing
import Foundation
@testable import Quack

/// Tests for tool call persistence, serialization, display data conversion,
/// and permission model.
@Suite("Tool Calls")
struct ToolCallTests {

    // MARK: - CompletedToolCallData Serialization

    @Test("Encode and decode completed tool calls roundtrip")
    @MainActor
    func completedToolCallRoundtrip() {
        let calls: [ChatService.ActiveToolCall] = [
            ChatService.ActiveToolCall(
                id: "call_1",
                name: "read_file",
                arguments: "{\"path\": \"src/main.swift\"}",
                state: .completed("file contents here")
            ),
            ChatService.ActiveToolCall(
                id: "call_2",
                name: "search",
                arguments: "{\"query\": \"TODO\"}",
                state: .failed("timeout after 30s")
            ),
        ]

        let json = ChatService.encodeCompletedToolCalls(calls)
        #expect(json != nil)

        let decoded = ChatService.decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 2)

        #expect(decoded[0].id == "call_1")
        #expect(decoded[0].name == "read_file")
        #expect(decoded[0].arguments == "{\"path\": \"src/main.swift\"}")
        #expect(decoded[0].result == "file contents here")
        #expect(decoded[0].isError == false)

        #expect(decoded[1].id == "call_2")
        #expect(decoded[1].name == "search")
        #expect(decoded[1].result == "timeout after 30s")
        #expect(decoded[1].isError == true)
    }

    @Test("Encode skips running tool calls")
    @MainActor
    func encodeSkipsRunning() {
        let calls: [ChatService.ActiveToolCall] = [
            ChatService.ActiveToolCall(id: "1", name: "tool", state: .running),
        ]

        let json = ChatService.encodeCompletedToolCalls(calls)
        #expect(json == nil)
    }

    @Test("Decode returns empty for nil JSON")
    @MainActor
    func decodeNilJSON() {
        let result = ChatService.decodeCompletedToolCalls(from: nil)
        #expect(result.isEmpty)
    }

    @Test("Decode returns empty for empty string")
    @MainActor
    func decodeEmptyString() {
        let result = ChatService.decodeCompletedToolCalls(from: "")
        #expect(result.isEmpty)
    }

    @Test("Decode returns empty for invalid JSON")
    @MainActor
    func decodeInvalidJSON() {
        let result = ChatService.decodeCompletedToolCalls(from: "not json")
        #expect(result.isEmpty)
    }

    // MARK: - ToolCallDisplayData

    @Test("DisplayData from ActiveToolCall preserves all fields")
    @MainActor
    func displayDataFromActive() {
        let active = ChatService.ActiveToolCall(
            id: "call_1",
            name: "read_file",
            arguments: "{\"path\": \"test.txt\"}",
            state: .completed("contents")
        )
        let display = ToolCallDisplayData(from: active)

        #expect(display.id == "call_1")
        #expect(display.name == "read_file")
        #expect(display.arguments == "{\"path\": \"test.txt\"}")
        if case .completed(let r) = display.state {
            #expect(r == "contents")
        } else {
            Issue.record("Expected .completed state")
        }
    }

    @Test("DisplayData from CompletedToolCallData preserves all fields")
    @MainActor
    func displayDataFromCompleted() {
        let completed = ChatService.CompletedToolCallData(
            id: "call_2",
            name: "search",
            arguments: "{\"q\": \"test\"}",
            result: "3 matches",
            isError: false
        )
        let display = ToolCallDisplayData(from: completed)

        #expect(display.id == "call_2")
        #expect(display.name == "search")
        #expect(display.arguments == "{\"q\": \"test\"}")
        if case .completed(let r) = display.state {
            #expect(r == "3 matches")
        } else {
            Issue.record("Expected .completed state")
        }
    }

    @Test("DisplayData from failed CompletedToolCallData sets failed state")
    @MainActor
    func displayDataFromFailed() {
        let completed = ChatService.CompletedToolCallData(
            id: "call_3",
            name: "exec",
            arguments: nil,
            result: "permission denied",
            isError: true
        )
        let display = ToolCallDisplayData(from: completed)

        if case .failed(let err) = display.state {
            #expect(err == "permission denied")
        } else {
            Issue.record("Expected .failed state")
        }
    }

    // MARK: - ToolPermission

    @Test("ToolPermission default is ask")
    @MainActor
    func defaultPermissionIsAsk() {
        let config = MCPServerConfig(name: "test", command: "echo")
        #expect(config.toolPermission == .ask)
    }

    @Test("ToolPermission roundtrips through raw value")
    @MainActor
    func permissionRoundtrip() {
        let config = MCPServerConfig(name: "test", command: "echo")

        config.toolPermission = .always
        #expect(config.toolPermission == .always)
        #expect(config.toolPermissionRaw == "always")

        config.toolPermission = .deny
        #expect(config.toolPermission == .deny)
        #expect(config.toolPermissionRaw == "deny")

        config.toolPermission = .ask
        #expect(config.toolPermission == .ask)
        #expect(config.toolPermissionRaw == "ask")
    }

    @Test("ToolPermission has all three cases")
    func allCases() {
        #expect(ToolPermission.allCases.count == 3)
        #expect(ToolPermission.allCases.contains(.always))
        #expect(ToolPermission.allCases.contains(.ask))
        #expect(ToolPermission.allCases.contains(.deny))
    }

    @Test("ToolPermission labels are human readable")
    @MainActor
    func labels() {
        #expect(ToolPermission.always.label == "Always Allow")
        #expect(ToolPermission.ask.label == "Ask")
        #expect(ToolPermission.deny.label == "Deny")
    }

    // MARK: - ChatService Approval State

    @Test("ChatService starts with no pending approval")
    @MainActor
    func noPendingApprovalInitially() {
        let service = ChatService()
        #expect(service.pendingApproval == nil)
        #expect(service.approvalContinuation == nil)
    }

    @Test("approveToolCall clears pending state")
    @MainActor
    func approveClears() {
        let service = ChatService()
        // Simulate having no continuation (safe to call)
        service.pendingApproval = ChatService.PendingToolApproval(
            id: "1", name: "test", arguments: "{}"
        )
        // approveToolCall without continuation should not crash
        service.approveToolCall()
        #expect(service.pendingApproval == nil)
    }

    @Test("denyToolCall clears pending state")
    @MainActor
    func denyClears() {
        let service = ChatService()
        service.pendingApproval = ChatService.PendingToolApproval(
            id: "1", name: "test", arguments: "{}"
        )
        service.denyToolCall()
        #expect(service.pendingApproval == nil)
    }

    // MARK: - Per-Session Per-Tool Permission Overrides

    @Test("Session starts with no tool permission overrides")
    @MainActor
    func noOverridesInitially() {
        let session = ChatSession(title: "Test")
        #expect(session.toolPermissionOverrides == nil)
        #expect(session.toolPermissionOverridesJSON == nil)
    }

    @Test("effectivePermission returns server default when no override")
    @MainActor
    func effectivePermissionFallsBack() {
        let session = ChatSession(title: "Test")
        #expect(session.effectivePermission(for: "read_file", serverDefault: .always) == .always)
        #expect(session.effectivePermission(for: "write_file", serverDefault: .deny) == .deny)
        #expect(session.effectivePermission(for: "search", serverDefault: .ask) == .ask)
    }

    @Test("setToolPermission stores override when different from server default")
    @MainActor
    func setOverrideDifferentFromDefault() {
        let session = ChatSession(title: "Test")

        session.setToolPermission(.deny, for: "dangerous_tool", serverDefault: .ask)

        #expect(session.effectivePermission(for: "dangerous_tool", serverDefault: .ask) == .deny)
        #expect(session.toolPermissionOverrides != nil)
        #expect(session.toolPermissionOverrides?["dangerous_tool"] == .deny)
    }

    @Test("setToolPermission clears override when same as server default")
    @MainActor
    func setOverrideSameAsDefault() {
        let session = ChatSession(title: "Test")

        // Set an override
        session.setToolPermission(.deny, for: "tool", serverDefault: .ask)
        #expect(session.toolPermissionOverrides?["tool"] == .deny)

        // Set back to server default — should clear the override
        session.setToolPermission(.ask, for: "tool", serverDefault: .ask)
        #expect(session.toolPermissionOverrides == nil)
    }

    @Test("setToolPermission with nil clears override")
    @MainActor
    func setNilClearsOverride() {
        let session = ChatSession(title: "Test")

        session.setToolPermission(.always, for: "tool", serverDefault: .ask)
        #expect(session.toolPermissionOverrides?["tool"] == .always)

        session.setToolPermission(nil, for: "tool", serverDefault: .ask)
        #expect(session.toolPermissionOverrides == nil)
    }

    @Test("Multiple per-tool overrides are independent")
    @MainActor
    func multipleOverrides() {
        let session = ChatSession(title: "Test")

        session.setToolPermission(.always, for: "read_file", serverDefault: .ask)
        session.setToolPermission(.deny, for: "exec_command", serverDefault: .ask)

        #expect(session.effectivePermission(for: "read_file", serverDefault: .ask) == .always)
        #expect(session.effectivePermission(for: "exec_command", serverDefault: .ask) == .deny)
        #expect(session.effectivePermission(for: "search", serverDefault: .ask) == .ask)

        let overrides = session.toolPermissionOverrides!
        #expect(overrides.count == 2)
    }

    @Test("toolPermissionOverrides JSON roundtrip")
    @MainActor
    func overridesRoundtrip() {
        let session = ChatSession(title: "Test")

        session.setToolPermission(.always, for: "tool_a", serverDefault: .ask)
        session.setToolPermission(.deny, for: "tool_b", serverDefault: .ask)

        // Read back
        let json = session.toolPermissionOverridesJSON
        #expect(json != nil)

        // Clear and re-set from JSON
        let session2 = ChatSession(title: "Test2")
        session2.toolPermissionOverridesJSON = json

        #expect(session2.effectivePermission(for: "tool_a", serverDefault: .ask) == .always)
        #expect(session2.effectivePermission(for: "tool_b", serverDefault: .ask) == .deny)
    }
}

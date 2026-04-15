import Testing
import Foundation
@testable import QuackKit

struct StreamingTypesTests {
    @Test func activeToolCallInit() {
        let call = ActiveToolCall(
            id: "tc_1", name: "readFile",
            arguments: "{\"path\": \"/tmp\"}", state: .running
        )
        #expect(call.id == "tc_1")
        #expect(call.name == "readFile")
        #expect(call.arguments == "{\"path\": \"/tmp\"}")
    }

    @Test func activeToolCallStates() {
        if case .running = ActiveToolCall(id: "1", name: "t", state: .running).state {} else { Issue.record("Expected running") }
        if case .completed(let r) = ActiveToolCall(id: "2", name: "t", state: .completed("result")).state {
            #expect(r == "result")
        } else { Issue.record("Expected completed") }
        if case .failed(let e) = ActiveToolCall(id: "3", name: "t", state: .failed("error")).state {
            #expect(e == "error")
        } else { Issue.record("Expected failed") }
    }

    @Test func pendingToolApproval() {
        let approval = PendingToolApproval(id: "pa_1", name: "writeFile", arguments: "{}")
        #expect(approval.id == "pa_1")
        #expect(approval.name == "writeFile")
        #expect(approval.arguments == "{}")
    }

    @Test func streamingSegmentText() {
        if case .text(let text) = StreamingSegment.text("Hello") {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected text segment")
        }
    }

    @Test func streamingSegmentToolCall() {
        if case .toolCall(let id) = StreamingSegment.toolCall(id: "tc_1") {
            #expect(id == "tc_1")
        } else {
            Issue.record("Expected tool call segment")
        }
    }

    @Test func builtInToolSummary() {
        let summary = BuiltInToolSummary(
            builtInTool: .readFile,
            name: "builtin-read_file",
            description: "Read the contents of a file."
        )
        #expect(summary.id == "builtin-read_file")
        #expect(summary.builtInTool == .readFile)
        #expect(summary.name == "builtin-read_file")
    }

    @Test func mcpToolSummary() {
        let summary = MCPToolSummary(name: "search", description: "Search the web")
        #expect(summary.id == "search")
        #expect(summary.name == "search")
        #expect(summary.description == "Search the web")
    }

    @Test func mcpServerState() {
        #expect(MCPServerState.connecting == .connecting)
        #expect(MCPServerState.connected == .connected)
        #expect(MCPServerState.disconnected == .disconnected)
        #expect(MCPServerState.error("test") == .error("test"))
        #expect(MCPServerState.error("a") != .error("b"))
        #expect(MCPServerState.connecting != .connected)
    }
}

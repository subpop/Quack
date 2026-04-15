import Testing
import Foundation
@testable import QuackKit

struct ChatServiceEncodingTests {
    @Test @MainActor func encodeCompletedToolCallsEmpty() {
        let result = ChatService.encodeCompletedToolCalls([])
        #expect(result == nil)
    }

    @Test @MainActor func encodeCompletedToolCallsCompleted() {
        let calls = [
            ActiveToolCall(id: "1", name: "readFile", arguments: "{\"path\":\"/tmp\"}", state: .completed("contents")),
        ]
        let json = ChatService.encodeCompletedToolCalls(calls)
        #expect(json != nil)

        let decoded = decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].id == "1")
        #expect(decoded[0].name == "readFile")
        #expect(decoded[0].result == "contents")
        #expect(decoded[0].isError == false)
    }

    @Test @MainActor func encodeCompletedToolCallsFailed() {
        let calls = [
            ActiveToolCall(id: "2", name: "writeFile", state: .failed("permission denied")),
        ]
        let json = ChatService.encodeCompletedToolCalls(calls)
        let decoded = decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].isError == true)
        #expect(decoded[0].result == "permission denied")
    }

    @Test @MainActor func encodeCompletedToolCallsRunning() {
        let calls = [
            ActiveToolCall(id: "3", name: "runCommand", state: .running),
        ]
        let json = ChatService.encodeCompletedToolCalls(calls)
        let decoded = decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].isError == true)
        #expect(decoded[0].result == "Tool call was interrupted.")
    }

    @Test @MainActor func encodeContentSegmentsEmpty() {
        let result = ChatService.encodeContentSegments([])
        #expect(result == nil)
    }

    @Test @MainActor func encodeContentSegmentsText() {
        let segments: [StreamingSegment] = [.text("Hello world")]
        let json = ChatService.encodeContentSegments(segments)
        #expect(json != nil)

        let decoded = decodeContentSegments(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].type == "text")
        #expect(decoded[0].value == "Hello world")
    }

    @Test @MainActor func encodeContentSegmentsToolCall() {
        let segments: [StreamingSegment] = [.toolCall(id: "tc_1")]
        let json = ChatService.encodeContentSegments(segments)
        let decoded = decodeContentSegments(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].type == "toolCall")
        #expect(decoded[0].value == "tc_1")
    }

    @Test @MainActor func encodeContentSegmentsMixed() {
        let segments: [StreamingSegment] = [
            .text("Before "),
            .toolCall(id: "tc_1"),
            .text("After"),
        ]
        let json = ChatService.encodeContentSegments(segments)
        let decoded = decodeContentSegments(from: json)
        #expect(decoded.count == 3)
    }

    @Test @MainActor func encodeContentSegmentsSkipsEmptyText() {
        let segments: [StreamingSegment] = [.text(""), .text("content")]
        let json = ChatService.encodeContentSegments(segments)
        let decoded = decodeContentSegments(from: json)
        #expect(decoded.count == 1)
        #expect(decoded[0].value == "content")
    }

    @Test @MainActor func encodeCompletedToolCallsMixed() {
        let calls = [
            ActiveToolCall(id: "1", name: "readFile", arguments: "{}", state: .completed("data")),
            ActiveToolCall(id: "2", name: "writeFile", state: .failed("error")),
            ActiveToolCall(id: "3", name: "runCommand", state: .running),
        ]
        let json = ChatService.encodeCompletedToolCalls(calls)
        let decoded = decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 3)
        #expect(decoded[0].isError == false)
        #expect(decoded[1].isError == true)
        #expect(decoded[2].isError == true)
    }
}

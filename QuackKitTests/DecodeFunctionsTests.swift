import Testing
import Foundation
@testable import QuackKit

struct DecodeFunctionsTests {
    @Test func decodeCompletedToolCallsNil() {
        let result = decodeCompletedToolCalls(from: nil)
        #expect(result.isEmpty)
    }

    @Test func decodeCompletedToolCallsEmpty() {
        let result = decodeCompletedToolCalls(from: "")
        #expect(result.isEmpty)
    }

    @Test func decodeCompletedToolCallsInvalidJSON() {
        let result = decodeCompletedToolCalls(from: "not json")
        #expect(result.isEmpty)
    }

    @Test func decodeCompletedToolCallsValid() throws {
        let calls = [
            CompletedToolCallData(id: "1", name: "tool_a", arguments: "{}", result: "ok", isError: false),
            CompletedToolCallData(id: "2", name: "tool_b", arguments: nil, result: "err", isError: true),
        ]
        let json = String(data: try JSONEncoder().encode(calls), encoding: .utf8)!
        let decoded = decodeCompletedToolCalls(from: json)
        #expect(decoded.count == 2)
        #expect(decoded[0].id == "1")
        #expect(decoded[0].name == "tool_a")
        #expect(decoded[0].isError == false)
        #expect(decoded[1].id == "2")
        #expect(decoded[1].isError == true)
    }

    @Test func decodeContentSegmentsNil() {
        let result = decodeContentSegments(from: nil)
        #expect(result.isEmpty)
    }

    @Test func decodeContentSegmentsEmpty() {
        let result = decodeContentSegments(from: "")
        #expect(result.isEmpty)
    }

    @Test func decodeContentSegmentsInvalidJSON() {
        let result = decodeContentSegments(from: "{bad}")
        #expect(result.isEmpty)
    }

    @Test func decodeContentSegmentsValid() throws {
        let segments = [
            ContentSegmentData(type: "text", value: "Hello "),
            ContentSegmentData(type: "toolCall", value: "tc_1"),
            ContentSegmentData(type: "text", value: " world"),
        ]
        let json = String(data: try JSONEncoder().encode(segments), encoding: .utf8)!
        let decoded = decodeContentSegments(from: json)
        #expect(decoded.count == 3)
        #expect(decoded[0].type == "text")
        #expect(decoded[0].value == "Hello ")
        #expect(decoded[1].type == "toolCall")
        #expect(decoded[1].value == "tc_1")
        #expect(decoded[2].type == "text")
        #expect(decoded[2].value == " world")
    }
}

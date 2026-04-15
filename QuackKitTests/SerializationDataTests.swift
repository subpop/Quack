import Testing
import Foundation
@testable import QuackKit

struct SerializationDataTests {
    @Test func completedToolCallDataInit() {
        let data = CompletedToolCallData(
            id: "tc_1", name: "readFile",
            arguments: "{\"path\": \"/tmp/test\"}", result: "file contents", isError: false
        )
        #expect(data.id == "tc_1")
        #expect(data.name == "readFile")
        #expect(data.arguments == "{\"path\": \"/tmp/test\"}")
        #expect(data.result == "file contents")
        #expect(data.isError == false)
    }

    @Test func completedToolCallDataCodable() throws {
        let original = CompletedToolCallData(
            id: "tc_1", name: "tool", arguments: "{}", result: "ok", isError: false
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CompletedToolCallData.self, from: encoded)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.arguments == original.arguments)
        #expect(decoded.result == original.result)
        #expect(decoded.isError == original.isError)
    }

    @Test func contentSegmentDataInit() {
        let text = ContentSegmentData(type: "text", value: "Hello world")
        #expect(text.type == "text")
        #expect(text.value == "Hello world")

        let toolCall = ContentSegmentData(type: "toolCall", value: "tc_123")
        #expect(toolCall.type == "toolCall")
        #expect(toolCall.value == "tc_123")
    }

    @Test func contentSegmentDataCodable() throws {
        let original = ContentSegmentData(type: "text", value: "content")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContentSegmentData.self, from: encoded)
        #expect(decoded.type == original.type)
        #expect(decoded.value == original.value)
    }
}

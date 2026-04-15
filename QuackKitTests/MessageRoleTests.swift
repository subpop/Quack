import Testing
import Foundation
@testable import QuackKit

struct MessageRoleTests {
    @Test func rawValues() {
        #expect(MessageRole.system.rawValue == "system")
        #expect(MessageRole.user.rawValue == "user")
        #expect(MessageRole.assistant.rawValue == "assistant")
        #expect(MessageRole.tool.rawValue == "tool")
    }

    @Test func codableRoundTrip() throws {
        for role in [MessageRole.system, .user, .assistant, .tool] {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
            #expect(decoded == role)
        }
    }

    @Test func decodingFromString() throws {
        let json = "\"assistant\""
        let data = Data(json.utf8)
        let role = try JSONDecoder().decode(MessageRole.self, from: data)
        #expect(role == .assistant)
    }
}

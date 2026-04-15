import Testing
import Foundation
@testable import QuackKit

struct ToolPermissionTests {
    @Test func rawValues() {
        #expect(ToolPermission.always.rawValue == "always")
        #expect(ToolPermission.ask.rawValue == "ask")
        #expect(ToolPermission.deny.rawValue == "deny")
    }

    @Test func labels() {
        #expect(ToolPermission.always.label == "Always Allow")
        #expect(ToolPermission.ask.label == "Ask")
        #expect(ToolPermission.deny.label == "Deny")
    }

    @Test func descriptions() {
        #expect(ToolPermission.always.description.contains("automatically"))
        #expect(ToolPermission.ask.description.contains("prompted"))
        #expect(ToolPermission.deny.description.contains("blocked"))
    }

    @Test func allCases() {
        #expect(ToolPermission.allCases.count == 3)
        #expect(ToolPermission.allCases.contains(.always))
        #expect(ToolPermission.allCases.contains(.ask))
        #expect(ToolPermission.allCases.contains(.deny))
    }

    @Test func codableRoundTrip() throws {
        for perm in ToolPermission.allCases {
            let data = try JSONEncoder().encode(perm)
            let decoded = try JSONDecoder().decode(ToolPermission.self, from: data)
            #expect(decoded == perm)
        }
    }
}

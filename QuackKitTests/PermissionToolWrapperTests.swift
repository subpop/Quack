import Testing
import Foundation
@testable import QuackKit

struct PermissionToolWrapperTests {
    struct MockTool: AnyTool, Sendable {
        typealias Context = QuackToolContext
        var name: String { "mock_tool" }
        var description: String { "A mock tool for testing." }
        var parametersSchema: JSONSchema { .object(properties: [:], required: []) }

        let executeResult: ToolResult

        init(result: ToolResult = .success("mock result")) {
            self.executeResult = result
        }

        func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
            return executeResult
        }
    }

    @Test func alwaysPermissionExecutes() async throws {
        let mock = MockTool(result: .success("done"))
        let wrapper = PermissionToolWrapper(
            wrapped: mock,
            permission: .always,
            onApprovalNeeded: { _, _, _ in false }
        )

        #expect(wrapper.name == "mock_tool")
        #expect(wrapper.description == "A mock tool for testing.")

        let result = try await wrapper.execute(arguments: Data("{}".utf8), context: QuackToolContext())
        #expect(result.content == "done")
        #expect(result.isError == false)
    }

    @Test func denyPermissionBlocks() async throws {
        let mock = MockTool()
        let wrapper = PermissionToolWrapper(
            wrapped: mock,
            permission: .deny,
            onApprovalNeeded: { _, _, _ in true }
        )

        let result = try await wrapper.execute(arguments: Data("{}".utf8), context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("denied"))
        #expect(result.content.contains("mock_tool"))
    }

    @Test func askPermissionApproved() async throws {
        let mock = MockTool(result: .success("approved result"))
        let wrapper = PermissionToolWrapper(
            wrapped: mock,
            permission: .ask,
            onApprovalNeeded: { name, _, _ in
                #expect(name == "mock_tool")
                return true
            }
        )

        let result = try await wrapper.execute(arguments: Data("{}".utf8), context: QuackToolContext())
        #expect(result.content == "approved result")
        #expect(result.isError == false)
    }

    @Test func askPermissionDenied() async throws {
        let mock = MockTool()
        let wrapper = PermissionToolWrapper(
            wrapped: mock,
            permission: .ask,
            onApprovalNeeded: { _, _, _ in false }
        )

        let result = try await wrapper.execute(arguments: Data("{}".utf8), context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("denied by user"))
    }

    @Test func wrapsSchemaFromInner() {
        let mock = MockTool()
        let wrapper = PermissionToolWrapper(
            wrapped: mock,
            permission: .always,
            onApprovalNeeded: { _, _, _ in false }
        )
        #expect(wrapper.parametersSchema == mock.parametersSchema)
    }
}

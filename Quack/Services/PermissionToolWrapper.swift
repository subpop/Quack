import Foundation
import AgentRunKit

/// Wraps an MCP tool to enforce permission checks before execution.
///
/// When the permission is `.ask`, the wrapper suspends execution and waits
/// for user approval via a continuation provided by `ChatService`.
/// When `.deny`, the tool returns an error without executing.
/// When `.always`, the tool executes normally.
struct PermissionToolWrapper: AnyTool, Sendable {
    typealias Context = EmptyContext

    let wrapped: any AnyTool<EmptyContext>
    let permission: ToolPermission
    let onApprovalNeeded: @Sendable (String, String, String) async -> Bool

    var name: String { wrapped.name }
    var description: String { wrapped.description }
    var parametersSchema: JSONSchema { wrapped.parametersSchema }

    func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        switch permission {
        case .always:
            return try await wrapped.execute(arguments: arguments, context: context)

        case .deny:
            return .error("Tool call denied: \(name) is blocked by permission settings.")

        case .ask:
            let argsString = String(data: arguments, encoding: .utf8) ?? "{}"
            let approved = await onApprovalNeeded(name, argsString, wrapped.description)
            if approved {
                return try await wrapped.execute(arguments: arguments, context: context)
            } else {
                return .error("Tool call denied by user.")
            }
        }
    }
}

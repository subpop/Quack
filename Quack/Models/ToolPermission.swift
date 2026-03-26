import Foundation

/// Controls whether tool calls from an MCP server are executed automatically,
/// require user approval, or are blocked entirely.
enum ToolPermission: String, CaseIterable, Codable {
    case always = "always"
    case ask = "ask"
    case deny = "deny"

    var label: String {
        switch self {
        case .always: "Always Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        }
    }

    var description: String {
        switch self {
        case .always: "Tool calls execute automatically without prompting."
        case .ask: "You will be prompted before each tool call executes."
        case .deny: "Tool calls from this server are blocked."
        }
    }
}

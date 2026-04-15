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

import Foundation

/// Controls whether tool calls from an MCP server are executed automatically,
/// require user approval, or are blocked entirely.
public enum ToolPermission: String, CaseIterable, Codable, Sendable {
    case always = "always"
    case ask = "ask"
    case deny = "deny"

    public var label: String {
        switch self {
        case .always: "Always Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        }
    }

    public var description: String {
        switch self {
        case .always: "Tool calls execute automatically without prompting."
        case .ask: "You will be prompted before each tool call executes."
        case .deny: "Tool calls from this server are blocked."
        }
    }
}

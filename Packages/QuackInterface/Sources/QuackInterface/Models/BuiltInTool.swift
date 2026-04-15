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

/// Defines the built-in tools that ship with Quack.
///
/// Each tool has a stable string identifier (namespaced with `builtin-`)
/// that is used for persistence in session/assistant tool permission overrides.
/// The `builtin-` prefix avoids collisions with MCP server tool names.
/// Names use only `[a-zA-Z0-9_-]` to satisfy LLM API tool-name constraints.
public enum BuiltInTool: String, CaseIterable, Codable, Identifiable, Sendable {
    case readFile = "builtin-read_file"
    case writeFile = "builtin-write_file"
    case runCommand = "builtin-run_command"
    case webFetch = "builtin-web_fetch"
    case webSearch = "builtin-web_search"

    public var id: String { rawValue }

    /// The subset of `allCases` whose build-time requirements are satisfied.
    ///
    /// Tools with `requiresBuildTimeKey == true` are only included when their
    /// API key was provided via `Secrets.xcconfig` at build time.
    public nonisolated(unsafe) static var availableCases: [BuiltInTool] {
        allCases.filter { tool in
            guard tool.requiresBuildTimeKey else { return true }
            guard let value = tool.buildTimeKey, !value.isEmpty else { return false }
            return true
        }
    }

    /// Human-readable display name shown in the UI.
    public var displayName: String {
        switch self {
        case .readFile: "Read File"
        case .writeFile: "Write File"
        case .runCommand: "Run Command"
        case .webFetch: "Web Fetch"
        case .webSearch: "Web Search"
        }
    }

    /// Description of what this tool does.
    public var toolDescription: String {
        switch self {
        case .readFile: "Read the contents of a file at a given path."
        case .writeFile: "Write content to a file at a given path."
        case .runCommand: "Execute a shell command and return its output."
        case .webFetch: "Fetch the content of a URL and return the response body."
        case .webSearch: "Search the web using Tavily and return relevant results."
        }
    }

    /// SF Symbol icon name for display.
    public var iconName: String {
        switch self {
        case .readFile: "doc.text"
        case .writeFile: "square.and.pencil"
        case .runCommand: "terminal"
        case .webFetch: "globe"
        case .webSearch: "magnifyingglass"
        }
    }

    /// Whether this tool requires a build-time API key to be available.
    ///
    /// Tools that return `true` are only registered when their key was
    /// provided via `Secrets.xcconfig` and baked into the binary by
    /// `scripts/generate-secrets.sh`.
    public nonisolated var requiresBuildTimeKey: Bool {
        switch self {
        case .webSearch: true
        default: false
        }
    }

    /// The obfuscated API key for this tool, read from the generated
    /// `Secrets` enum. Returns `nil` for tools that don't require one
    /// or when the key was not provided at build time.
    public nonisolated var buildTimeKey: String? {
        switch self {
        case .webSearch: "" // TODO: inject at runtime
        default: nil
        }
    }
}

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
import AgentRunKit
import QuackInterface

/// Built-in tool that shows diffs from a Git repository's working tree or between refs.
public struct GitDiffTool: AnyTool, Sendable {
    public typealias Context = QuackToolContext

    public var name: String { "builtin-git_diff" }
    public var description: String { "Show changes in the working tree or between commits." }
    public var isReadOnly: Bool { true }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "files": .array(
                    items: .string(),
                    description: "Specific files to diff. Defaults to all files."
                ).optional(),
                "staged": .boolean(description: "If true, diff staged (cached) changes instead of unstaged working tree changes.").optional(),
                "base": .string(description: "Base ref for comparison (e.g. \"HEAD~3\", \"main\"). Defaults to HEAD for staged diffs, or the index for unstaged diffs.").optional(),
            ],
            required: []
        )
    }

    public func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
        struct Args: Decodable {
            let files: [String]?
            let staged: Bool?
            let base: String?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"files\": [...], \"staged\": bool, \"base\": \"...\" }")
        }

        var gitArgs = ["diff"]

        if let base = args.base {
            gitArgs.append(base)
        } else if args.staged == true {
            gitArgs.append("--cached")
        }

        if let files = args.files, !files.isEmpty {
            gitArgs.append("--")
            gitArgs += files
        }

        let result = runGit(gitArgs, workingDirectory: context.workingDirectory)

        switch result {
        case .failure(let message):
            return .error(message)
        case .success(let output):
            if output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                return .success("No differences found.")
            }
            return .success(output)
        }
    }
}

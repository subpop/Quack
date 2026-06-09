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

/// Built-in tool that returns recent commit history from a Git repository.
public struct GitLogTool: AnyTool, Sendable {
    public typealias Context = QuackToolContext

    public var name: String { "builtin-git_log" }
    public var description: String { "Show recent commit history of a Git repository." }
    public var isReadOnly: Bool { true }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "count": .integer(description: "Number of commits to return. Defaults to 10.").optional(),
                "file": .string(description: "Limit history to commits that modified this file path.").optional(),
                "author": .string(description: "Filter commits by author name or email.").optional(),
            ],
            required: []
        )
    }

    public func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
        struct Args: Decodable {
            let count: Int?
            let file: String?
            let author: String?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"count\": N, \"file\": \"...\", \"author\": \"...\" }")
        }

        let limit = args.count ?? 10

        var gitArgs = [
            "log",
            "--format=%H %ad %an%n  %s",
            "--date=short",
            "-\(limit)",
        ]

        if let author = args.author {
            gitArgs.append("--author=\(author)")
        }

        if let file = args.file {
            gitArgs += ["--", file]
        }

        let result = runGit(gitArgs, workingDirectory: context.workingDirectory)

        switch result {
        case .failure(let message):
            return .error(message)
        case .success(let output):
            if output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                return .success("No commits found.")
            }
            return .success(output)
        }
    }
}

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

/// Built-in tool that stages files and creates a Git commit.
public struct GitCommitTool: AnyTool, Sendable {
    public typealias Context = QuackToolContext

    public var name: String { "builtin-git_commit" }
    public var description: String { "Stage files and create a commit in a Git repository." }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "message": .string(description: "The commit message."),
                "files": .array(
                    items: .string(),
                    description: "Files to stage before committing. If omitted, all changes are staged (git add -A)."
                ).optional(),
            ],
            required: ["message"]
        )
    }

    public func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
        struct Args: Decodable {
            let message: String
            let files: [String]?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"message\": \"...\", \"files\": [...] }")
        }

        // Stage files
        let addArgs: [String]
        if let files = args.files, !files.isEmpty {
            addArgs = ["add", "--"] + files
        } else {
            addArgs = ["add", "-A"]
        }

        let addResult = runGit(addArgs, workingDirectory: context.workingDirectory)
        if case .failure(let message) = addResult {
            return .error("Failed to stage files: \(message)")
        }

        // Commit
        let commitResult = runGit(
            ["commit", "-m", args.message],
            workingDirectory: context.workingDirectory
        )

        switch commitResult {
        case .failure(let message):
            return .error(message)
        case .success(let output):
            return .success(output)
        }
    }
}

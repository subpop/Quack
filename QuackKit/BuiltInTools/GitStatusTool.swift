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

/// Built-in tool that returns structured working tree status from a Git repository.
public struct GitStatusTool: AnyTool, Sendable {
    public typealias Context = QuackToolContext

    public var name: String { "builtin-git_status" }
    public var description: String { "Show the working tree status of a Git repository." }
    public var isReadOnly: Bool { true }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "path": .string(description: "Subdirectory or file to scope the status to. Defaults to the entire repository.").optional(),
            ],
            required: []
        )
    }

    public func execute(arguments: Data, context: QuackToolContext) async throws -> ToolResult {
        struct Args: Decodable {
            let path: String?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"path\": \"...\" }")
        }

        var gitArgs = ["status", "--porcelain=v1"]
        if let path = args.path {
            gitArgs += ["--", path]
        }

        let result = runGit(gitArgs, workingDirectory: context.workingDirectory)

        switch result {
        case .failure(let message):
            return .error(message)
        case .success(let output):
            if output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                return .success("Clean working tree — no changes.")
            }

            var staged: [String] = []
            var unstaged: [String] = []
            var untracked: [String] = []

            for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
                guard line.count >= 3 else { continue }
                let index = line[line.startIndex]
                let worktree = line[line.index(line.startIndex, offsetBy: 1)]
                let file = String(line.dropFirst(3))

                if index == "?" {
                    untracked.append(file)
                } else {
                    if index != " " {
                        staged.append("\(index) \(file)")
                    }
                    if worktree != " " {
                        unstaged.append("\(worktree) \(file)")
                    }
                }
            }

            var sections: [String] = []
            if !staged.isEmpty {
                sections.append("Staged:\n" + staged.map { "  \($0)" }.joined(separator: "\n"))
            }
            if !unstaged.isEmpty {
                sections.append("Unstaged:\n" + unstaged.map { "  \($0)" }.joined(separator: "\n"))
            }
            if !untracked.isEmpty {
                sections.append("Untracked:\n" + untracked.map { "  \($0)" }.joined(separator: "\n"))
            }

            return .success(sections.joined(separator: "\n\n"))
        }
    }
}

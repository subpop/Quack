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

/// Built-in tool that executes a shell command and returns its output.
public struct RunCommandTool: AnyTool, Sendable {
    public typealias Context = EmptyContext

    public var name: String { "builtin-run_command" }
    public var description: String { "Execute a shell command and return its output." }

    public init() {}

    public var parametersSchema: JSONSchema {
        .object(
            properties: [
                "command": .string(description: "The command to execute (e.g. \"ls\", \"python3\", \"git\")."),
                "arguments": .array(
                    items: .string(),
                    description: "Arguments to pass to the command."
                ).optional(),
                "workingDirectory": .string(description: "The working directory for the command. Defaults to the user's home directory.").optional(),
            ],
            required: ["command"]
        )
    }

    public func execute(arguments: Data, context: EmptyContext) async throws -> ToolResult {
        struct Args: Decodable {
            let command: String
            let arguments: [String]?
            let workingDirectory: String?
        }

        let args: Args
        do {
            args = try JSONDecoder().decode(Args.self, from: arguments)
        } catch {
            return .error("Invalid arguments: expected { \"command\": \"...\", \"arguments\": [...] }")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let fullCommand: String
        if let cmdArgs = args.arguments, !cmdArgs.isEmpty {
            let escaped = cmdArgs.map { arg in
                "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
            }
            fullCommand = "\(args.command) \(escaped.joined(separator: " "))"
        } else {
            fullCommand = args.command
        }
        process.arguments = ["-l", "-c", fullCommand]

        if let workDir = args.workingDirectory {
            let expandedPath = NSString(string: workDir).expandingTildeInPath
            process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return .error("Failed to execute command: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus

        var result = ""
        if !stdout.isEmpty {
            result += stdout
        }
        if !stderr.isEmpty {
            if !result.isEmpty { result += "\n" }
            result += "stderr:\n\(stderr)"
        }
        if result.isEmpty {
            result = "(no output)"
        }

        if exitCode != 0 {
            return .error("Command exited with code \(exitCode)\n\(result)")
        }

        return .success(result)
    }
}

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

/// The result of running a `git` command.
enum GitResult: Sendable {
    case success(String)
    case failure(String)
}

/// Runs a `git` command with the given arguments and returns the output.
///
/// - Parameters:
///   - arguments: The arguments to pass to `git` (e.g. `["status", "--porcelain=v1"]`).
///   - workingDirectory: The directory in which to run the command.
/// - Returns: `.success` with stdout on exit code 0,
///   or `.failure` with a descriptive error message otherwise.
nonisolated func runGit(
    _ arguments: [String],
    workingDirectory: String?
) -> GitResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments

    if let workDir = workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        return .failure("Failed to run git: \(error.localizedDescription)")
    }

    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        let message = stderr.isEmpty ? stdout : stderr
        return .failure("git exited with code \(process.terminationStatus): \(message)")
    }

    return .success(stdout)
}

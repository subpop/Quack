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

/// Discovers and reads project-level instruction files (AGENTS.md, CLAUDE.md)
/// by walking up from the working directory toward the filesystem root, returns the first match
/// found. Only project-level discovery is supported (no global instruction files).
public enum InstructionFileService {

    /// The filenames to search for, in priority order.
    /// The first match wins — if AGENTS.md is found, CLAUDE.md is not also loaded.
    private static let filenames = ["AGENTS.md", "CLAUDE.md"]

    /// Discover and read instruction files by walking up from `workingDirectory`.
    ///
    /// Returns a formatted string ready for injection into the system prompt,
    /// or `nil` if no instruction file was found or the directory is not set.
    ///
    /// The returned string is prefixed with the source path for transparency:
    /// ```
    /// Instructions from: /path/to/project/AGENTS.md
    /// <file content>
    /// ```
    public static func loadInstructions(workingDirectory: String?) -> String? {
        guard let workDir = workingDirectory else { return nil }

        let startURL = URL(fileURLWithPath: workDir, isDirectory: true).standardized
        let rootURL = URL(fileURLWithPath: "/", isDirectory: true)

        // Walk upward from the working directory to the filesystem root.
        var currentURL = startURL
        while true {
            // Check each filename at the current directory level.
            for filename in filenames {
                let candidateURL = currentURL.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: candidateURL.path) {
                    // Found a match — read and return it.
                    guard let content = try? String(contentsOf: candidateURL, encoding: .utf8),
                          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else {
                        // File exists but is empty or unreadable — skip it.
                        continue
                    }
                    return "Instructions from: \(candidateURL.path)\n<file content>\n\(content)</file content>\n"
                }
            }

            // Move to the parent directory.
            let parentURL = currentURL.deletingLastPathComponent().standardized
            if parentURL == currentURL || currentURL == rootURL {
                // Reached the filesystem root without finding anything.
                break
            }
            currentURL = parentURL
        }

        return nil
    }
}

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

/// Tool context carrying per-session dependencies to built-in tools.
///
/// Replaces `EmptyContext` throughout the tool chain so that tools can access
/// session-scoped state such as the working directory.
public struct QuackToolContext: ToolContext, Sendable {
    /// The working directory for file and command tools.
    /// When set, `RunCommandTool` uses this as the default CWD,
    /// and `ReadFileTool`/`WriteFileTool` resolve relative paths against it.
    public let workingDirectory: String?

    public init(workingDirectory: String? = nil) {
        self.workingDirectory = workingDirectory
    }
}

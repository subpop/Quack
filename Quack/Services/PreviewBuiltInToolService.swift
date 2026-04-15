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
import Observation
import QuackInterface
import AgentRunKit

/// A minimal no-op ``BuiltInToolServiceProtocol`` implementation for SwiftUI previews.
@Observable
@MainActor
final class PreviewBuiltInToolService: BuiltInToolServiceProtocol {
    var enabledTools: Set<BuiltInTool> = Set(BuiltInTool.availableCases)
    var defaultPermissions: [BuiltInTool: ToolPermission] = [:]
    var enabledToolSummaries: [BuiltInToolSummary] = []

    func setEnabled(_ enabled: Bool, for tool: BuiltInTool) {}
    func setDefaultPermission(_ permission: ToolPermission, for tool: BuiltInTool) {}
    func isEnabled(_ tool: BuiltInTool) -> Bool { enabledTools.contains(tool) }
    func defaultPermission(for tool: BuiltInTool) -> ToolPermission { .ask }

    func tools(
        for session: ChatSession,
        onApprovalNeeded: @escaping @Sendable @concurrent (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] { [] }
}

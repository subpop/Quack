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
import SwiftUI
import AgentRunKit

// MARK: - Promoted Types

/// Lightweight description of an enabled built-in tool for UI display.
public struct BuiltInToolSummary: Identifiable, Sendable {
    public let builtInTool: BuiltInTool
    public let name: String
    public let description: String
    public var id: String { name }

    public init(builtInTool: BuiltInTool, name: String, description: String) {
        self.builtInTool = builtInTool
        self.name = name
        self.description = description
    }
}

// MARK: - Protocol

@MainActor
public protocol BuiltInToolServiceProtocol: AnyObject, Observable {
    /// Which built-in tools are globally enabled.
    var enabledTools: Set<BuiltInTool> { get }

    /// Global default permission for each built-in tool.
    var defaultPermissions: [BuiltInTool: ToolPermission] { get }

    /// All globally-enabled built-in tools as summaries (for UI display).
    var enabledToolSummaries: [BuiltInToolSummary] { get }

    /// Enable or disable a specific built-in tool globally.
    func setEnabled(_ enabled: Bool, for tool: BuiltInTool)

    /// Set the global default permission for a specific built-in tool.
    func setDefaultPermission(_ permission: ToolPermission, for tool: BuiltInTool)

    /// Whether a specific built-in tool is globally enabled.
    func isEnabled(_ tool: BuiltInTool) -> Bool

    /// The global default permission for a specific built-in tool.
    func defaultPermission(for tool: BuiltInTool) -> ToolPermission

    /// Returns permission-wrapped built-in tools for a specific chat session.
    func tools(
        for session: ChatSession,
        onApprovalNeeded: @escaping @Sendable (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>]
}

// MARK: - Environment Key

private struct BuiltInToolServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any BuiltInToolServiceProtocol = PlaceholderBuiltInToolService()
}

public extension EnvironmentValues {
    var builtInToolService: any BuiltInToolServiceProtocol {
        get { self[BuiltInToolServiceKey.self] }
        set { self[BuiltInToolServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderBuiltInToolService: BuiltInToolServiceProtocol {
    var enabledTools: Set<BuiltInTool> = []
    var defaultPermissions: [BuiltInTool: ToolPermission] = [:]
    var enabledToolSummaries: [BuiltInToolSummary] = []

    func setEnabled(_ enabled: Bool, for tool: BuiltInTool) {}
    func setDefaultPermission(_ permission: ToolPermission, for tool: BuiltInTool) {}
    func isEnabled(_ tool: BuiltInTool) -> Bool { false }
    func defaultPermission(for tool: BuiltInTool) -> ToolPermission { .ask }

    func tools(
        for session: ChatSession,
        onApprovalNeeded: @escaping @Sendable (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] { [] }
}

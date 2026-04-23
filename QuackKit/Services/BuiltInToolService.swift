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
import os
import OSLog
import QuackInterface

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.subpop.Quack", category: "BuiltInToolService")

/// Manages the global configuration of built-in tools (enabled state and
/// default permissions) and provides permission-wrapped tool instances
/// for chat sessions.
///
/// Global settings are persisted to a JSON file in the app's Application
/// Support directory. Per-session and per-assistant overrides are stored
/// in SwiftData fields on `ChatSession` and `Assistant` using the same
/// `toolPermissionOverridesJSON` / `toolPermissionDefaultsJSON` mechanism
/// as MCP tools, keyed by the built-in tool's `rawValue` (e.g. `"builtin.read_file"`).
@Observable
@MainActor
public final class BuiltInToolService: BuiltInToolServiceProtocol {

    // MARK: - Observable State

    /// Which built-in tools are globally enabled.
    public private(set) var enabledTools: Set<BuiltInTool> = Set(BuiltInTool.availableCases)

    /// Global default permission for each built-in tool.
    public private(set) var defaultPermissions: [BuiltInTool: ToolPermission] = {
        var defaults: [BuiltInTool: ToolPermission] = [:]
        for tool in BuiltInTool.availableCases {
            defaults[tool] = .ask
        }
        return defaults
    }()

    // MARK: - Private

    /// The tool instances, created once and reused.
    ///
    /// Tools that require a build-time API key (via `Secrets.xcconfig`) are
    /// only included when the key was provided and obfuscated into the binary
    /// by `scripts/generate-secrets.sh`.
    private let toolInstances: [BuiltInTool: any AnyTool<EmptyContext>] = {
        var tools: [BuiltInTool: any AnyTool<EmptyContext>] = [
            .readFile: ReadFileTool(),
            .writeFile: WriteFileTool(),
            .runCommand: RunCommandTool(),
            .webFetch: WebFetchTool(),
            .activateSkill: ActivateSkillTool(),
        ]

        // Register WebSearch only when a Tavily API key was provided at
        // build time via Secrets.xcconfig.
        if let key = SecretsProvider.tavilyAPIKey, !key.isEmpty {
            tools[.webSearch] = WebSearchTool()
        }

        return tools
    }()

    private let settingsURL: URL

    // MARK: - Init

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDir = appSupport.appendingPathComponent("app.subpop.Quack")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.settingsURL = appDir.appendingPathComponent("builtin-tools.json")
        load()
    }

    /// Test-only initializer that uses an in-memory configuration.
    public init(settingsURL: URL) {
        self.settingsURL = settingsURL
        load()
    }

    // MARK: - Mutation

    /// Enable or disable a specific built-in tool globally.
    public func setEnabled(_ enabled: Bool, for tool: BuiltInTool) {
        if enabled {
            enabledTools.insert(tool)
        } else {
            enabledTools.remove(tool)
        }
        save()
    }

    /// Set the global default permission for a specific built-in tool.
    public func setDefaultPermission(_ permission: ToolPermission, for tool: BuiltInTool) {
        defaultPermissions[tool] = permission
        save()
    }

    /// Whether a specific built-in tool is globally enabled.
    public func isEnabled(_ tool: BuiltInTool) -> Bool {
        enabledTools.contains(tool)
    }

    /// The global default permission for a specific built-in tool.
    public func defaultPermission(for tool: BuiltInTool) -> ToolPermission {
        defaultPermissions[tool] ?? .ask
    }

    // MARK: - Tool Provisioning

    /// Returns permission-wrapped built-in tools for a specific chat session.
    ///
    /// Only tools that are both globally enabled AND enabled for the session
    /// are returned. Each tool is wrapped with the effective permission
    /// (session override > global default).
    public func tools(
        for session: ChatSession,
        onApprovalNeeded: @escaping @Sendable @concurrent (String, String, String) async -> Bool
    ) -> [any AnyTool<EmptyContext>] {
        let sessionEnabledIDs = session.enabledBuiltInToolIDs ?? []

        return BuiltInTool.availableCases.compactMap { tool -> (any AnyTool<EmptyContext>)? in
            // Don't register activate_skill when no skills are discovered.
            if tool == .activateSkill,
               SkillService.shared?.allDiscoveredSkills.isEmpty != false {
                return nil
            }

            // Must be globally enabled AND enabled for this session
            guard enabledTools.contains(tool),
                  sessionEnabledIDs.contains(tool.rawValue),
                  let instance = toolInstances[tool]
            else { return nil }

            let globalDefault = defaultPermissions[tool] ?? .ask
            let effectivePermission = session.effectivePermission(
                for: tool.rawValue,
                serverDefault: globalDefault
            )

            return PermissionToolWrapper(
                wrapped: instance,
                permission: effectivePermission,
                onApprovalNeeded: onApprovalNeeded
            ) as any AnyTool<EmptyContext>
        }
    }

    /// Returns all globally-enabled built-in tools as summaries (for UI display).
    public var enabledToolSummaries: [BuiltInToolSummary] {
        BuiltInTool.availableCases.compactMap { tool in
            guard enabledTools.contains(tool),
                  let instance = toolInstances[tool]
            else { return nil }
            return BuiltInToolSummary(builtInTool: tool, name: instance.name, description: instance.description)
        }
    }

    // MARK: - Persistence

    private struct PersistedSettings: Codable {
        var enabledToolIDs: [String]
        var defaultPermissions: [String: String]
    }

    private func save() {
        let settings = PersistedSettings(
            enabledToolIDs: enabledTools.map(\.rawValue),
            defaultPermissions: defaultPermissions.reduce(into: [:]) { result, pair in
                result[pair.key.rawValue] = pair.value.rawValue
            }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            logger.error("Failed to save built-in tool settings: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(PersistedSettings.self, from: data)

            enabledTools = Set(
                settings.enabledToolIDs.compactMap { BuiltInTool(rawValue: $0) }
            )

            defaultPermissions = settings.defaultPermissions.reduce(into: [:]) { result, pair in
                if let tool = BuiltInTool(rawValue: pair.key),
                   let permission = ToolPermission(rawValue: pair.value) {
                    result[tool] = permission
                }
            }
        } catch {
            logger.error("Failed to load built-in tool settings: \(error)")
        }
    }
}

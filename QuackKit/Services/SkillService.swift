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
import os
import SwiftData
import Observation
import CryptoKit
import QuackInterface

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "app.subpop.Quack",
    category: "SkillService"
)

// MARK: - Discovered Skill

/// A skill discovered on the filesystem, held transiently in memory.
///
/// Unlike `AgentSkill` (a SwiftData model for repository-installed skills),
/// discovered skills are ephemeral and re-scanned on each launch.
public struct DiscoveredSkill: Identifiable, Sendable, Hashable {
    /// Unique ID derived from the skill name.
    public var id: String { name }

    /// Skill name extracted from SKILL.md frontmatter.
    public let name: String

    /// Description extracted from SKILL.md frontmatter.
    public let description: String

    /// Absolute path to the SKILL.md file.
    public let location: URL

    /// Parent directory of SKILL.md — the skill's base directory.
    public let baseDirectory: URL

    /// Where this skill was discovered from.
    public let source: DiscoverySource

    public enum DiscoverySource: Sendable, Hashable {
        /// From `~/.agents/skills/`
        case userAgents
        /// From Quack's Library store (repository-installed)
        case libraryStore
    }
}

/// Manages the lifecycle of agent skills: discovery, install, update,
/// uninstall, and system prompt catalog composition.
///
/// Skills are discovered from two locations:
/// 1. `~/.agents/skills/` — cross-client convention (transient, in-memory)
/// 2. `~/Library/Application Support/app.subpop.Quack/skills/` — repository-installed (SwiftData)
///
/// The service follows the Agent Skills progressive disclosure model:
/// - A lightweight catalog (name + description) is injected into the system prompt
/// - The model activates skills on demand via the `activate_skill` built-in tool
/// - Resources are loaded individually via existing file-read tools
@Observable
@MainActor
public final class SkillService: SkillServiceProtocol {

    // MARK: - Singleton

    // This singleton is used by ActivateSkillTool to access skill content.
    // QuackToolContext now exists but SkillService is kept as a singleton
    // rather than carried in the context to avoid circular dependencies
    // between QuackInterface (where QuackToolContext lives) and QuackKit
    // (where SkillService lives).
    public static var shared: SkillService?

    // MARK: - Observable State

    public private(set) var installedSkills: [AgentSkill] = []
    /// Internal discovered skills with full detail.
    public private(set) var allDiscoveredSkills: [DiscoveredSkill] = []

    /// Protocol-conforming discovered skills list for UI consumers.
    public var discoveredSkills: [DiscoveredSkillInfo] {
        allDiscoveredSkills.map {
            DiscoveredSkillInfo(name: $0.name, description: $0.description, locationPath: $0.location.path)
        }
    }
    public var lastError: String? = nil
    public private(set) var isProcessing: Bool = false

    // MARK: - Private

    private let skillsDirectory: URL
    private let userAgentsSkillsDirectory: URL

    // MARK: - Init

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDir = appSupport.appendingPathComponent("app.subpop.Quack")
        self.skillsDirectory = appDir.appendingPathComponent("skills")

        let home = FileManager.default.homeDirectoryForCurrentUser
        self.userAgentsSkillsDirectory = home
            .appendingPathComponent(".agents")
            .appendingPathComponent("skills")

        try? FileManager.default.createDirectory(
            at: skillsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Discovery

    /// Scan all skill directories and build the unified discovered skills list.
    ///
    /// Scans:
    /// 1. `~/.agents/skills/` — cross-client convention
    /// 2. Quack's Library store — repository-installed skills
    ///
    /// Library store skills take precedence over `~/.agents/skills/` on name collision.
    public func scanForSkills() {
        var result: [String: DiscoveredSkill] = [:]

        // Tier 1: ~/.agents/skills/ (lower precedence)
        let userSkills = scanDirectory(userAgentsSkillsDirectory, source: .userAgents)
        for skill in userSkills {
            result[skill.name] = skill
        }

        // Tier 2: Library store (higher precedence — overwrites on collision)
        let librarySkills = scanDirectory(skillsDirectory, source: .libraryStore)
        for skill in librarySkills {
            if result[skill.name] != nil {
                logger.info("Library skill '\(skill.name)' shadows ~/.agents/skills/ version")
            }
            result[skill.name] = skill
        }

        // Filter out disabled installed skills
        let disabledNames = Set(installedSkills.filter { !$0.isEnabled }.map(\.name))
        let filtered = result.values
            .filter { !disabledNames.contains($0.name) }
            .sorted { $0.name < $1.name }

        allDiscoveredSkills = filtered

        logger.info("Discovered \(filtered.count) skill(s) (\(userSkills.count) from ~/.agents/skills/, \(librarySkills.count) from Library store)")
    }

    /// Scan a single directory for skill subdirectories containing SKILL.md.
    private func scanDirectory(_ directory: URL, source: DiscoveredSkill.DiscoverySource) -> [DiscoveredSkill] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: directory.path) else { return [] }

        guard let subdirs = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var skills: [DiscoveredSkill] = []

        for subdir in subdirs {
            // Skip non-directories
            guard let values = try? subdir.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true
            else { continue }

            let skillMD = subdir.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD.path) else { continue }

            // Parse frontmatter
            guard let content = try? String(contentsOf: skillMD, encoding: .utf8) else {
                logger.warning("Failed to read SKILL.md at \(skillMD.path)")
                continue
            }

            let frontMatter = parseFrontMatter(content)

            guard let name = frontMatter["name"], !name.isEmpty else {
                logger.warning("SKILL.md at \(skillMD.path) has no name field, skipping")
                continue
            }

            guard let description = frontMatter["description"], !description.isEmpty else {
                logger.warning("SKILL.md at \(skillMD.path) has no description field, skipping")
                continue
            }

            skills.append(DiscoveredSkill(
                name: name,
                description: description,
                location: skillMD,
                baseDirectory: subdir,
                source: source
            ))
        }

        return skills
    }

    // MARK: - Skill Installation

    /// Clone a repository and discover all skills it contains, without installing them.
    ///
    /// The cloned files are cached in the Library store so that
    /// `installDiscoveredSkills` can persist them without re-downloading.
    public func discoverSkills(from source: String) async throws -> [DiscoverableSkill] {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        let repoURL = normalizeSource(source)
        guard !repoURL.isEmpty else {
            throw SkillError.invalidSource(source)
        }

        // Check if already installed
        if installedSkills.contains(where: { $0.source == repoURL }) {
            throw SkillError.alreadyInstalled(repoURL)
        }

        // Clone and extract all skills from the repo
        let extracted = try await downloadSkills(repoURL: repoURL)

        return extracted.map {
            DiscoverableSkill(name: $0.name, description: $0.description)
        }
    }

    /// Install previously discovered skills by name.
    ///
    /// The skill files must already be present in the Library store
    /// (placed there by `discoverSkills`).
    public func installDiscoveredSkills(
        _ skills: [DiscoverableSkill],
        from source: String,
        modelContext: ModelContext
    ) throws {
        let repoURL = normalizeSource(source)
        let selectedNames = Set(skills.map(\.name))

        for preview in skills {
            // Verify the skill directory exists (placed by downloadSkills)
            let skillDir = skillsDirectory.appendingPathComponent(preview.name)
            let skillMD = skillDir.appendingPathComponent("SKILL.md")
            guard FileManager.default.fileExists(atPath: skillMD.path) else {
                logger.warning("Skill directory for '\(preview.name)' not found, skipping")
                continue
            }

            // Compute content hash
            if let content = try? String(contentsOf: skillMD, encoding: .utf8) {
                let hash = SHA256.hash(data: Data(content.utf8))
                let contentHash = hash.map { String(format: "%02x", $0) }.joined()

                let skill = AgentSkill(
                    name: preview.name,
                    source: repoURL,
                    skillDescription: preview.description,
                    isEnabled: true
                )
                skill.contentHash = contentHash
                skill.contentPath = "skills/\(preview.name)"
                modelContext.insert(skill)
            }
        }

        // Clean up any downloaded-but-not-selected skill directories
        if let allDirs = try? FileManager.default.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            let installedNames = Set(installedSkills.map(\.name))
            for dir in allDirs {
                let name = dir.lastPathComponent
                guard let values = try? dir.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true,
                      !selectedNames.contains(name),
                      !installedNames.contains(name)
                else { continue }
                try? FileManager.default.removeItem(at: dir)
            }
        }

        try modelContext.save()

        reloadSkills(modelContext: modelContext)
        scanForSkills()

        let names = skills.map(\.name).joined(separator: ", ")
        logger.info("Installed \(skills.count) skill(s) from \(repoURL): \(names)")
    }

    /// Install all skills from a Git repository (convenience method).
    ///
    /// Clones the repo, discovers all skills, and installs them all
    /// without user selection. For UI flows that need a picker, use
    /// `discoverSkills(from:)` followed by `installDiscoveredSkills(_:from:modelContext:)`.
    public func installSkill(from source: String, modelContext: ModelContext) async throws {
        let discovered = try await discoverSkills(from: source)
        try installDiscoveredSkills(discovered, from: source, modelContext: modelContext)
    }

    // MARK: - Skill Uninstall

    public func uninstallSkill(_ skill: AgentSkill, modelContext: ModelContext) {
        // Remove cached files
        let skillDir = skillsDirectory.appendingPathComponent(skill.name)
        try? FileManager.default.removeItem(at: skillDir)

        // Remove SwiftData record
        modelContext.delete(skill)
        try? modelContext.save()

        // Refresh
        reloadSkills(modelContext: modelContext)
        scanForSkills()

        logger.info("Uninstalled skill '\(skill.name)'")
    }

    // MARK: - Skill Update

    public func updateSkill(_ skill: AgentSkill, modelContext: ModelContext) async throws {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        // Re-clone the source repo to check for updates
        let extracted = try await downloadSkills(repoURL: skill.source)

        // Find the matching skill entry by name
        if let entry = extracted.first(where: { $0.name == skill.name }) {
            if let newDescription = entry.description {
                skill.skillDescription = newDescription
            }
            skill.contentHash = entry.contentHash
            skill.updatedAt = Date()
            try modelContext.save()
        }

        reloadSkills(modelContext: modelContext)
        scanForSkills()

        logger.info("Updated skill '\(skill.name)'")
    }

    // MARK: - Enable/Disable

    public func setEnabled(_ enabled: Bool, for skill: AgentSkill, modelContext: ModelContext) {
        skill.isEnabled = enabled
        try? modelContext.save()
        reloadSkills(modelContext: modelContext)
        scanForSkills()
    }

    // MARK: - Content Reading

    /// Read the SKILL.md content for a discovered skill by name.
    ///
    /// This is the primary method used by the `activate_skill` tool.
    public func skillContent(forName name: String) -> String? {
        guard let skill = allDiscoveredSkills.first(where: { $0.name == name }) else {
            return nil
        }
        return try? String(contentsOf: skill.location, encoding: .utf8)
    }

    /// Get the base directory for a discovered skill by name.
    public func skillBaseDirectory(forName name: String) -> URL? {
        allDiscoveredSkills.first(where: { $0.name == name })?.baseDirectory
    }

    /// Read the SKILL.md content for a specific installed skill by ID.
    public func skillContent(for skillID: UUID) -> String? {
        guard let skill = installedSkills.first(where: { $0.id == skillID }) else {
            return nil
        }

        let skillDir = skillsDirectory.appendingPathComponent(skill.name)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")

        guard FileManager.default.fileExists(atPath: skillFile.path) else {
            return nil
        }

        return try? String(contentsOf: skillFile, encoding: .utf8)
    }

    /// Read the raw SKILL.md content for an installed skill (by reference).
    public func skillContent(for skill: AgentSkill) -> String? {
        let skillDir = skillsDirectory.appendingPathComponent(skill.name)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")

        guard FileManager.default.fileExists(atPath: skillFile.path) else {
            return nil
        }

        return try? String(contentsOf: skillFile, encoding: .utf8)
    }

    /// Get the file size of the SKILL.md for a specific skill.
    public func skillFileSize(for skill: AgentSkill) -> Int? {
        let skillDir = skillsDirectory.appendingPathComponent(skill.name)
        let skillFile = skillDir.appendingPathComponent("SKILL.md")

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: skillFile.path),
              let size = attrs[.size] as? Int
        else { return nil }

        return size
    }

    /// Enumerate bundled resource files in a skill directory.
    ///
    /// Returns relative paths for files in `references/`, `scripts/`, and
    /// `assets/` subdirectories. Used by the `activate_skill` tool to
    /// surface available resources to the model.
    public func enumerateResources(forName name: String) -> [String] {
        guard let baseDir = skillBaseDirectory(forName: name) else { return [] }
        let fm = FileManager.default

        var resources: [String] = []
        let resourceDirs = ["references", "scripts", "assets"]

        for dirName in resourceDirs {
            let dir = baseDir.appendingPathComponent(dirName)
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true
                else { continue }

                resources.append("\(dirName)/\(file.lastPathComponent)")
            }
        }

        return resources.sorted()
    }

    // MARK: - System Prompt Composition

    /// Compose a system prompt with always-enabled skills injected directly
    /// and remaining skills listed in a lightweight catalog.
    ///
    /// Always-enabled skills have their full SKILL.md body injected into the
    /// prompt (wrapped in `<skill_content>` tags). Remaining discovered skills
    /// appear in a lightweight catalog for on-demand activation via the
    /// `activate_skill` tool.
    ///
    /// Returns `nil` when there is no base prompt and no discovered skills.
    public func composedSystemPrompt(
        basePrompt: String?,
        alwaysEnabledSkillNames: [String]
    ) -> String? {
        // If no skills discovered, return the base prompt unchanged
        guard !allDiscoveredSkills.isEmpty else {
            return basePrompt
        }

        let alwaysEnabledSet = Set(alwaysEnabledSkillNames)

        // Partition skills into always-enabled vs. catalog-only
        let alwaysEnabled = allDiscoveredSkills.filter { alwaysEnabledSet.contains($0.name) }
        let catalogOnly = allDiscoveredSkills.filter { !alwaysEnabledSet.contains($0.name) }

        var parts: [String] = []

        if let base = basePrompt, !base.isEmpty {
            parts.append(base)
        }

        // Inject always-enabled skills with full content
        for skill in alwaysEnabled {
            guard let rawContent = try? String(contentsOf: skill.location, encoding: .utf8) else {
                continue
            }

            let body = stripFrontMatter(rawContent)
            let resources = enumerateResources(forName: skill.name)

            var block = "<skill_content name=\"\(skill.name)\">\n"
            block += body
            block += "\n\nSkill directory: \(skill.baseDirectory.path)"
            block += "\nRelative paths in this skill are relative to the skill directory."

            if !resources.isEmpty {
                block += "\n\n<skill_resources>"
                for resource in resources {
                    block += "\n<file>\(resource)</file>"
                }
                block += "\n</skill_resources>"
            }

            block += "\n</skill_content>"
            parts.append(block)
        }

        // Build catalog for remaining skills (if any)
        if !catalogOnly.isEmpty {
            var catalog = """
            Skills provide specialized instructions for particular tasks.
            When a task matches a skill's description, call the activate_skill tool
            with the skill's name to load its full instructions before proceeding.

            <available_skills>
            """

            for skill in catalogOnly {
                catalog += """

                <skill>
                <name>\(skill.name)</name>
                <description>\(skill.description)</description>
                <location>\(skill.location.path)</location>
                </skill>
                """
            }

            catalog += "\n</available_skills>"
            parts.append(catalog)
        }

        // If we have no parts at all, return nil
        guard !parts.isEmpty else { return nil }

        return parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Reload

    public func reloadSkills(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<AgentSkill>(
            sortBy: [SortDescriptor(\.name)]
        )
        installedSkills = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Front Matter Utilities (Internal for ActivateSkillTool)

    /// Strip YAML front matter from content, returning only the body.
    public func stripFrontMatter(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return content
        }

        var endIndex = 1
        for (i, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                endIndex = i + 2 // +1 for dropFirst offset, +1 to skip the closing ---
                break
            }
        }

        return lines.dropFirst(endIndex)
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    // MARK: - Private Helpers

    /// Normalize a source string to a canonical Git URL.
    ///
    /// Accepts HTTPS, HTTP, SSH (`git@host:path`), and `ssh://` URLs.
    /// Strips trailing `.git` and `/` for consistent deduplication.
    private func normalizeSource(_ source: String) -> String {
        var s = source.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing .git
        if s.hasSuffix(".git") {
            s = String(s.dropLast(4))
        }

        // Strip trailing slash
        if s.hasSuffix("/") {
            s = String(s.dropLast())
        }

        // Validate: must be a recognized Git URL scheme
        let isHTTP = s.hasPrefix("https://") || s.hasPrefix("http://")
        let isSSH = s.hasPrefix("ssh://") || s.contains("@") && s.contains(":")

        guard isHTTP || isSSH else { return "" }

        return s
    }

    /// A single extracted skill entry from a downloaded repository.
    private struct ExtractedSkill {
        let name: String
        let description: String?
        let contentHash: String
    }

    /// Clone a skill repository and extract all skills found.
    ///
    /// A single repo may contain one or many skills. Returns an entry for
    /// each discovered SKILL.md. Supports any Git-compatible URL.
    private func downloadSkills(
        repoURL: String
    ) async throws -> [ExtractedSkill] {
        let gitPath = "/usr/bin/git"
        guard FileManager.default.fileExists(atPath: gitPath) else {
            throw SkillError.gitNotFound
        }

        // Clone into a temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cloneDir = tempDir.appendingPathComponent("repo")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = ["clone", "--depth", "1", repoURL, cloneDir.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrData = pipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            throw SkillError.cloneFailed(repoURL, stderr)
        }

        // Find all SKILL.md files in the cloned repo
        let skillMDPaths = findAllSkillMDs(in: cloneDir)

        guard !skillMDPaths.isEmpty else {
            throw SkillError.noSkillMDFound(repoURL)
        }

        // Process each SKILL.md
        var results: [ExtractedSkill] = []

        for skillMDPath in skillMDPaths {
            let content = try String(contentsOf: skillMDPath, encoding: .utf8)
            let frontMatter = parseFrontMatter(content)
            let skillName = frontMatter["name"]
                ?? skillMDPath.deletingLastPathComponent().lastPathComponent
            let description = frontMatter["description"]

            // Compute content hash
            let hashData = Data(content.utf8)
            let hash = SHA256.hash(data: hashData)
            let contentHash = hash.map { String(format: "%02x", $0) }.joined()

            // Copy skill directory to permanent storage
            let destDir = skillsDirectory.appendingPathComponent(skillName)

            // Remove existing if present (for updates)
            if FileManager.default.fileExists(atPath: destDir.path) {
                try FileManager.default.removeItem(at: destDir)
            }

            // Copy the entire skill directory (parent of SKILL.md)
            let sourceSkillDir = skillMDPath.deletingLastPathComponent()
            try FileManager.default.copyItem(at: sourceSkillDir, to: destDir)

            results.append(ExtractedSkill(
                name: skillName,
                description: description,
                contentHash: contentHash
            ))
        }

        return results
    }

    /// Search for all SKILL.md files in the extracted repository.
    ///
    /// Checks multiple conventional locations:
    /// 1. Root: `SKILL.md` (single-skill repo)
    /// 2. Well-known subdirectories: `skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`
    ///    (multi-skill repos like JuliusBrussee/caveman)
    /// 3. Any top-level subdirectory: `*/SKILL.md` (e.g. `swiftui-pro/SKILL.md`
    ///    in twostraws/SwiftUI-Agent-Skill)
    ///
    /// Deduplicates by skill name (from frontmatter or directory name).
    /// Well-known locations (steps 1-2) take precedence over the top-level
    /// fallback (step 3) when the same skill name appears in both.
    private func findAllSkillMDs(in repoDir: URL) -> [URL] {
        let fm = FileManager.default

        // Keyed by skill name to deduplicate
        var found: [String: URL] = [:]

        func skillName(for skillMDURL: URL) -> String {
            // Try to extract name from frontmatter
            if let content = try? String(contentsOf: skillMDURL, encoding: .utf8) {
                let fm = parseFrontMatter(content)
                if let name = fm["name"], !name.isEmpty {
                    return name
                }
            }
            // Fall back to parent directory name
            return skillMDURL.deletingLastPathComponent().lastPathComponent
        }

        func addIfNew(_ url: URL) {
            guard fm.fileExists(atPath: url.path) else { return }
            let name = skillName(for: url)
            // Don't overwrite — first discovery wins (well-known paths are checked first)
            if found[name] == nil {
                found[name] = url
            }
        }

        // 1. Check root SKILL.md (single-skill repo)
        addIfNew(repoDir.appendingPathComponent("SKILL.md"))

        // 2. Check well-known skill directories (multi-skill repos)
        let skillsDirs = ["skills", ".agents/skills"]
        for dir in skillsDirs {
            let skillsPath = repoDir.appendingPathComponent(dir)
            if let subdirs = try? fm.contentsOfDirectory(
                at: skillsPath,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                for subdir in subdirs {
                    guard let values = try? subdir.resourceValues(forKeys: [.isDirectoryKey]),
                          values.isDirectory == true
                    else { continue }

                    addIfNew(subdir.appendingPathComponent("SKILL.md"))
                }
            }
        }

        // 3. Check any top-level subdirectory (single-skill repos with
        //    the skill in a named subdirectory at the repo root).
        //    Only adds skills not already found in steps 1-2.
        if let topLevelItems = try? fm.contentsOfDirectory(
            at: repoDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            for item in topLevelItems {
                guard let values = try? item.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true
                else { continue }

                addIfNew(item.appendingPathComponent("SKILL.md"))
            }
        }

        return Array(found.values)
    }

    /// Parse YAML front matter from a SKILL.md file.
    ///
    /// Front matter is delimited by `---` at the start of the file:
    /// ```
    /// ---
    /// name: my-skill
    /// description: A useful skill.
    /// ---
    /// ```
    func parseFrontMatter(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return result
        }

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }

            // Simple key: value parsing
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = trimmed[trimmed.startIndex..<colonIndex]
                    .trimmingCharacters(in: .whitespaces)
                var value = trimmed[trimmed.index(after: colonIndex)...]
                    .trimmingCharacters(in: .whitespaces)

                // Strip surrounding quotes
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }

                result[key] = value
            }
        }

        return result
    }
}

// MARK: - Errors

public enum SkillError: LocalizedError {
    case invalidSource(String)
    case alreadyInstalled(String)
    case cloneFailed(String, String)
    case gitNotFound
    case noSkillMDFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSource(let source):
            "Invalid skill source: \(source). Expected a valid Git URL."
        case .alreadyInstalled(let source):
            "Skill from \(source) is already installed."
        case .cloneFailed(let source, let stderr):
            "Failed to clone \(source).\(stderr.isEmpty ? "" : " \(stderr)")"
        case .gitNotFound:
            "Git is required to install skills. Install Xcode Command Line Tools with `xcode-select --install`."
        case .noSkillMDFound(let source):
            "No SKILL.md found in repository \(source)."
        }
    }
}

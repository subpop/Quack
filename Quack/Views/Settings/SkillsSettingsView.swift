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

import SwiftUI
import SwiftData
import QuackInterface

struct SkillsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.skillService) private var skillService
    @Query(sort: \AgentSkill.name) private var skills: [AgentSkill]

    @State private var editingSkill: AgentSkill?
    @State private var skillToDelete: AgentSkill?
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            if !skills.isEmpty {
                Section("Installed Skills") {
                    ForEach(skills) { skill in
                        SkillRow(skill: skill)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingSkill = skill
                            }
                            .contextMenu {
                                Button("View Details\u{2026}") {
                                    editingSkill = skill
                                }

                                Divider()

                                Toggle("Enabled", isOn: Binding(
                                    get: { skill.isEnabled },
                                    set: { newValue in
                                        skillService.setEnabled(newValue, for: skill, modelContext: modelContext)
                                    }
                                ))

                                Button("Update") {
                                    Task {
                                        try? await skillService.updateSkill(skill, modelContext: modelContext)
                                    }
                                }

                                Divider()

                                Button("Delete\u{2026}", role: .destructive) {
                                    skillToDelete = skill
                                }
                            }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .overlay {
            if skills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills Installed", systemImage: "sparkles")
                } description: {
                    Text("Skills provide expert knowledge to assistants via the system prompt.")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Add a Skill\u{2026}") {
                    showingAddSheet = true
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onAppear {
            skillService.reloadSkills(modelContext: modelContext)
        }
        .sheet(item: $editingSkill) { skill in
            SkillDetailSheet(skill: skill)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSkillSheet()
        }
        .alert(
            "Delete Skill",
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                skillToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let skill = skillToDelete {
                    skillService.uninstallSkill(skill, modelContext: modelContext)
                }
                skillToDelete = nil
            }
        } message: {
            if let skill = skillToDelete {
                Text("Are you sure you want to delete \"\(skill.name)\"? This will remove the skill and its cached content.")
            }
        }
    }
}

// MARK: - Skill Row

private struct SkillRow: View {
    let skill: AgentSkill
    @Environment(\.skillService) private var skillService

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.purple.gradient)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .fontWeight(.medium)
                Text(skill.source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("Updated \(skill.updatedAt, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let size = skillService.skillFileSize(for: skill) {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if !skill.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Skill Sheet

private struct AddSkillSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.skillService) private var skillService
    @Environment(\.dismiss) private var dismiss

    @State private var source: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // Multi-skill picker state
    @State private var discoveredSkills: [DiscoverableSkill] = []
    @State private var selectedSkills: Set<String> = []
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.purple.gradient)
                    )

                Text("Add a Skill")
                    .font(.headline)
                Text("Enter a Git repository URL.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            if showingPicker {
                skillPickerContent
            } else {
                sourceInputContent
            }
        }
        .frame(width: 420, height: showingPicker ? max(320, CGFloat(discoveredSkills.count * 44 + 220)) : 320)
        .animation(.default, value: showingPicker)
    }

    // MARK: - Source Input

    private var sourceInputContent: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Source", text: $source, prompt: Text("https://github.com/owner/repo"))
                    .font(.system(.body, design: .monospaced))

                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .imageScale(.small)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                }

                Button("Add") {
                    fetchSkills()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(source.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Skill Picker

    private var skillPickerContent: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(discoveredSkills) { skill in
                        Toggle(isOn: Binding(
                            get: { selectedSkills.contains(skill.name) },
                            set: { isOn in
                                if isOn {
                                    selectedSkills.insert(skill.name)
                                } else {
                                    selectedSkills.remove(skill.name)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name)
                                    .fontWeight(.medium)
                                if let desc = skill.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Found \(discoveredSkills.count) skills")
                } footer: {
                    Text("Select the skills you want to install.")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Select All") {
                    selectedSkills = Set(discoveredSkills.map(\.name))
                }

                Button("Select None") {
                    selectedSkills.removeAll()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Install \(selectedSkills.count) Skill\(selectedSkills.count == 1 ? "" : "s")") {
                    installSelected()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedSkills.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Actions

    private func fetchSkills() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let skills = try await skillService.discoverSkills(from: source)

                if skills.count <= 1 {
                    // Single skill — install directly
                    try skillService.installDiscoveredSkills(
                        skills, from: source, modelContext: modelContext
                    )
                    dismiss()
                } else {
                    // Multiple skills — show picker
                    discoveredSkills = skills
                    selectedSkills = Set(skills.map(\.name))
                    showingPicker = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func installSelected() {
        let toInstall = discoveredSkills.filter { selectedSkills.contains($0.name) }
        do {
            try skillService.installDiscoveredSkills(
                toInstall, from: source, modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Skill Detail Sheet (Proposal B)

struct SkillDetailSheet: View {
    @Bindable var skill: AgentSkill

    @Environment(\.modelContext) private var modelContext
    @Environment(\.skillService) private var skillService
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var isUpdating = false
    @State private var showFullContent = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            sheetForm
            Divider()
            sheetFooter
        }
        .frame(width: 500, height: 600)
        .alert(
            "Delete Skill",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                skillService.uninstallSkill(skill, modelContext: modelContext)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(skill.name)\"? This will remove the skill and its cached content.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.purple.gradient)
                )

            Text(skill.name)
                .font(.headline)

            Text(skill.source)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Form

    private var sheetForm: some View {
        Form {
            // Details
            Section("Details") {
                LabeledContent("Source", value: skill.source)

                if let hash = skill.contentHash {
                    LabeledContent("Version", value: String(hash.prefix(12)) + "\u{2026}")
                }

                LabeledContent("Installed") {
                    Text(skill.installedAt, format: .dateTime.month(.wide).day().year())
                }

                if let size = skillService.skillFileSize(for: skill) {
                    let tokenEstimate = size / 4
                    LabeledContent("Size") {
                        Text("\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) (~\(tokenEstimate.formatted()) tokens)")
                    }
                }

                if let description = skill.skillDescription, !description.isEmpty {
                    LabeledContent("Description", value: description)
                }

                // Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if isUpdating {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Button("Check for Update") {
                            updateSkill()
                        }
                        .font(.caption)
                    }
                }
            }

            // Enabled toggle
            Section {
                Toggle("Enabled", isOn: Binding(
                    get: { skill.isEnabled },
                    set: { newValue in
                        skillService.setEnabled(newValue, for: skill, modelContext: modelContext)
                    }
                ))
            } footer: {
                Text("Disabled skills are installed but not available for selection in assistants or sessions.")
            }

            // Content Preview
            Section("Content Preview") {
                if let content = skillService.skillContent(for: skill) {
                    let displayContent = showFullContent ? content : String(content.prefix(1000))
                    ScrollView {
                        Text(displayContent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: showFullContent ? 300 : 150)

                    if content.count > 1000 {
                        Button(showFullContent ? "Show Less" : "Show More\u{2026}") {
                            withAnimation {
                                showFullContent.toggle()
                            }
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Content not available.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            Button("Delete\u{2026}", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func updateSkill() {
        isUpdating = true
        Task {
            try? await skillService.updateSkill(skill, modelContext: modelContext)
            isUpdating = false
        }
    }
}

// MARK: - Previews

#Preview("Skills Settings") {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    SkillsSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}

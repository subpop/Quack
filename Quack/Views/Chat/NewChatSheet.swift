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
import UniformTypeIdentifiers
import QuackInterface

/// Sheet for creating a new chat session with optional configuration,
/// including a working directory for project-scoped file and command operations.
struct NewChatSheet: View {
    let assistants: [Assistant]
    let onCreate: (Assistant?, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedAssistantID: UUID?
    @State private var workingDirectoryPath: String = ""
    @State private var showFolderPicker = false

    private var resolvedAssistant: Assistant? {
        if let id = selectedAssistantID {
            return assistants.first { $0.id == id }
        }
        return assistants.first(where: \.isDefault) ?? assistants.first
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if assistants.count > 1 {
                    Picker("Assistant", selection: assistantBinding) {
                        ForEach(assistants) { assistant in
                            HStack {
                                Image(systemName: assistant.resolvedIcon)
                                Text(assistant.name)
                            }
                            .tag(assistant.id)
                        }
                    }
                }

                Section {
                    if workingDirectoryPath.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("General Session")
                                    .font(.system(.body, design: .rounded, weight: .medium))

                                Text("No working directory set")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Set\u{2026}") {
                                showFolderPicker = true
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.blue)
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Project Session")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(directoryDisplayName(workingDirectoryPath))
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(workingDirectoryPath)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }

                            Spacer()

                            Button("Change\u{2026}") {
                                showFolderPicker = true
                            }
                            .controlSize(.small)

                            Button("Clear") {
                                workingDirectoryPath = ""
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Working Directory")
                }
            }
            .formStyle(.grouped)
            .padding(.bottom, 4)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    let workDir = workingDirectoryPath.isEmpty ? nil : workingDirectoryPath
                    onCreate(resolvedAssistant, workDir)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 440, idealWidth: 480)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workingDirectoryPath = url.path(percentEncoded: false)
            }
        }
    }

    private func directoryDisplayName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var assistantBinding: Binding<UUID> {
        Binding {
            selectedAssistantID
                ?? assistants.first(where: \.isDefault)?.id
                ?? assistants.first?.id
                ?? UUID()
        } set: {
            selectedAssistantID = $0
        }
    }
}

#Preview {
    NewChatSheet(assistants: []) { _, _ in }
}

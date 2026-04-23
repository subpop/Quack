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

                LabeledContent("Working Directory") {
                    HStack {
                        TextField(
                            "None (optional)",
                            text: $workingDirectoryPath
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("Choose...") {
                            showFolderPicker = true
                        }

                        if !workingDirectoryPath.isEmpty {
                            Button {
                                workingDirectoryPath = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear working directory")
                        }
                    }
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

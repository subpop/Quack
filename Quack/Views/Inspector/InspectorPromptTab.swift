// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData
import QuackInterface

/// Displays the system prompt editor with an AI-powered prompt generation popover.
struct InspectorPromptTab: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext

    @State private var showingPromptGenerator = false
    @State private var agentDescription = ""
    @State private var isGeneratingPrompt = false

    var body: some View {
        Form {
            Section("System Prompt") {
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: systemPromptBinding)
                        .font(.body.monospaced())
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)

                    Button {
                        showingPromptGenerator = true
                    } label: {
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Generate system prompt")
                    .popover(isPresented: $showingPromptGenerator) {
                        promptGeneratorPopover
                    }
                }

                if session.systemPrompt != nil {
                    Button("Clear") {
                        session.systemPrompt = nil
                        save()
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Prompt Generator Popover

    private var promptGeneratorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate System Prompt")
                .font(.headline)

            TextField(
                "A coding assistant that specializes in Swift.",
                text: $agentDescription,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                if isGeneratingPrompt {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Generate") {
                    generateSystemPrompt()
                }
                .disabled(
                    agentDescription.trimmingCharacters(in: .whitespaces).isEmpty
                        || isGeneratingPrompt
                )
            }
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Actions

    private func generateSystemPrompt() {
        isGeneratingPrompt = true
        Task {
            let prompt = await TextGenerationService.generateSystemPrompt(
                from: agentDescription
            )
            session.systemPrompt = prompt
            save()
            isGeneratingPrompt = false
            showingPromptGenerator = false
            agentDescription = ""
        }
    }

    // MARK: - Bindings

    private var systemPromptBinding: Binding<String> {
        Binding(
            get: { session.systemPrompt ?? "" },
            set: { newValue in
                session.systemPrompt = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    let container = PreviewSupport.container
    let data = PreviewSupport.seed(container)

    InspectorPromptTab(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 400)
}

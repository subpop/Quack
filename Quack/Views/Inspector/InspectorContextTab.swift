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

/// Displays skills toggles and context management settings (compaction threshold, max messages).
struct InspectorContextTab: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.skillService) private var skillService

    var body: some View {
        Form {
            skillsSection
            contextSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        Section("Skills") {
            let discovered = skillService.discoveredSkills

            if discovered.isEmpty {
                Text("No skills available.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(discovered) { skill in
                    Toggle(
                        skill.name,
                        isOn: alwaysEnabledSkillBinding(for: skill.name)
                    )
                }
            }
        }
    }

    // MARK: - Context Management Section

    private var contextSection: some View {
        Section("Context Management") {
            LabeledContent(content: {
                Slider(
                    value: compactionBinding,
                    in: 0.3...0.95,
                    step: 0.05
                )
                if session.compactionThreshold != nil {
                    Button {
                        session.compactionThreshold = nil
                        save()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default")
                }
            }, label: {
                Text("Compaction Threshold")
                Text("When to summarize context.")
            })

            LabeledContent(content: {
                TextField(
                    "",
                    value: $session.maxMessages,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxMessages) { save() }
            }, label: {
                Text("Maximum Messages")
                Text("Limit messages sent to the model.")
            })
        }
    }

    // MARK: - Bindings

    private func alwaysEnabledSkillBinding(for skillName: String) -> Binding<Bool> {
        Binding(
            get: {
                session.alwaysEnabledSkillNames?.contains(skillName) ?? false
            },
            set: { isEnabled in
                var names = session.alwaysEnabledSkillNames ?? []
                if isEnabled {
                    if !names.contains(skillName) { names.append(skillName) }
                } else {
                    names.removeAll { $0 == skillName }
                }
                session.alwaysEnabledSkillNames = names.isEmpty ? nil : names
                save()
            }
        )
    }

    private var compactionBinding: Binding<Double> {
        Binding(
            get: { session.compactionThreshold ?? 0.7 },
            set: { newValue in
                session.compactionThreshold = newValue
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

    InspectorContextTab(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 400)
}

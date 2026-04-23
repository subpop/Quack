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

/// Displays model selection (provider and model pickers) and inference parameters
/// (temperature, max tokens, reasoning effort, max tool rounds).
struct InspectorModelTab: View {
    @Bindable var session: ChatSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerService) private var providerService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    var body: some View {
        Form {
            modelSection
            parametersSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section("Model") {
            let fallback = providerService.fallbackProfile(from: profiles)

            Picker("Provider", selection: providerBinding) {
                Text("Default (\(fallback?.name ?? "None"))")
                    .tag(nil as UUID?)
                Divider()
                ForEach(profiles.filter(\.isEnabled)) { profile in
                    Text(profile.name).tag(profile.id as UUID?)
                }
            }

            let effectiveProfile = providerService.resolvedProfile(for: session, profiles: profiles)

            if let effectiveProfile {
                ModelPicker(
                    selection: modelBinding,
                    profile: effectiveProfile,
                    placeholder: "Default (\(providerService.resolvedModel(for: session, profiles: profiles)))"
                )
            }
        }
    }

    // MARK: - Parameters Section

    private var parametersSection: some View {
        Section("Parameters") {
            // Temperature
            LabeledContent(content: {
                Slider(
                    value: temperatureBinding,
                    in: 0...2,
                    step: 0.1
                )
                if session.temperature != nil {
                    Button {
                        session.temperature = nil
                        save()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default")
                }
            }, label: {
                Text("Temperature")
                Text("Controls randomness of responses.")
            })

            // Max Tokens
            LabeledContent(content: {
                TextField(
                    "",
                    value: $session.maxTokens,
                    format: .number,
                    prompt: Text(effectiveMaxTokensPlaceholder)
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxTokens) { save() }
            }, label: {
                Text("Maximum Tokens")
                Text("Max output length per response.")
            })

            // Reasoning Effort
            LabeledContent(content: {
                Picker("", selection: reasoningBinding) {
                    Text("Default").tag(nil as String?)
                    Divider()
                    Text("None").tag("none" as String?)
                    Text("Low").tag("low" as String?)
                    Text("Medium").tag("medium" as String?)
                    Text("High").tag("high" as String?)
                    Text("Extra High").tag("xhigh" as String?)
                }
                .labelsHidden()
            }, label: {
                Text("Reasoning")
                Text("Thinking depth for capable models.")
            })

            // Max Tool Rounds
            LabeledContent(content: {
                TextField(
                    "",
                    value: $session.maxToolRounds,
                    format: .number,
                    prompt: Text("10")
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: session.maxToolRounds) { save() }
            }, label: {
                Text("Max Tool Rounds")
                Text("Tool-calling iterations per response.")
            })
        }
    }

    // MARK: - Bindings

    private var effectiveMaxTokensPlaceholder: String {
        let profile = providerService.resolvedProfile(for: session, profiles: profiles)
        let tokens = profile?.maxTokens ?? 4096
        return tokens.formatted()
    }

    private var providerBinding: Binding<UUID?> {
        Binding(
            get: { session.providerID },
            set: { newValue in
                session.providerID = newValue
                save()
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { session.modelIdentifier ?? "" },
            set: { newValue in
                session.modelIdentifier = newValue.isEmpty ? nil : newValue
                save()
            }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { session.temperature ?? 1.0 },
            set: { newValue in
                session.temperature = newValue
                save()
            }
        )
    }

    private var reasoningBinding: Binding<String?> {
        Binding(
            get: { session.reasoningEffort },
            set: { newValue in
                session.reasoningEffort = newValue
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

    InspectorModelTab(session: data.session)
        .previewEnvironment(container: container)
        .frame(width: 320, height: 500)
}

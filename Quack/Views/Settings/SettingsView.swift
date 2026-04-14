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

struct SettingsView: View {
    @ObservedObject var updater: SoftwareUpdater

    var body: some View {
        TabView {
            Tab("Assistants", systemImage: "person.2") {
                AssistantsSettingsView()
            }

            Tab("Providers", systemImage: "cloud") {
                ProvidersSettingsView()
            }

            Tab("Tools", systemImage: "wrench.and.screwdriver") {
                ToolsSettingsView()
            }

            Tab("Local Models", systemImage: "cpu") {
                LocalModelsSettingsView()
            }

            Tab("Updates", systemImage: "arrow.triangle.2.circlepath") {
                Form {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }
                .padding()
            }
        }
        .frame(width: 600, height: 480)
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    SettingsView(updater: SoftwareUpdater())
        .previewEnvironment(container: container)
}

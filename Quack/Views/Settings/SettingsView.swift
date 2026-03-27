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

            Tab("MCP Servers", systemImage: "puzzlepiece.extension") {
                MCPSettingsView()
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

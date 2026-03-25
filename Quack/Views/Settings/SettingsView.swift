import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }

            Tab("Providers", systemImage: "cloud") {
                ProvidersSettingsView()
            }

            Tab("MCP Servers", systemImage: "puzzlepiece.extension") {
                MCPSettingsView()
            }
        }
        .frame(width: 600, height: 480)
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    SettingsView()
        .previewEnvironment(container: container)
}

import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    @AppStorage("defaultSystemPrompt") private var defaultSystemPrompt = ""

    private var defaultProvider: Provider? {
        guard let id = providerService.defaultProviderID else { return nil }
        return providers.first { $0.id == id }
    }

    var body: some View {
        Form {
            Section("New Chats") {
                Picker("Provider", selection: Binding(
                    get: { providerService.defaultProviderID },
                    set: { providerService.defaultProviderID = $0 }
                )) {
                    Text("None").tag(nil as UUID?)
                    Divider()
                    ForEach(providers.filter(\.isEnabled)) { provider in
                        Label {
                            Text(provider.name)
                        } icon: {
                            if provider.kind.isCustomIcon {
                                provider.kind.icon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                provider.kind.icon
                            }
                        }
                        .tag(provider.id as UUID?)
                    }
                }

                if let provider = defaultProvider {
                    LabeledContent("Model") {
                        Text(provider.defaultModel)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                TextField("System Prompt", text: $defaultSystemPrompt, axis: .vertical)
                    .lineLimit(4...10)
            } header: {
                Text("Default System Prompt")
            } footer: {
                Text("Applied to all new chats. Override per chat in the inspector.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    GeneralSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 600, height: 480)
}

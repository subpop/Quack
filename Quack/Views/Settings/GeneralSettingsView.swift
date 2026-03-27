import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \ProviderProfile.sortOrder) private var profiles: [ProviderProfile]

    @AppStorage("defaultSystemPrompt") private var defaultSystemPrompt = ""

    private var defaultProfile: ProviderProfile? {
        guard let id = providerService.defaultProviderID else { return nil }
        return profiles.first { $0.id == id }
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
                    ForEach(profiles.filter(\.isEnabled)) { profile in
                        Label {
                            Text(profile.name)
                        } icon: {
                            if profile.platform.isCustomIcon {
                                profile.platform.icon
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                profile.platform.icon
                            }
                        }
                        .tag(profile.id as UUID?)
                    }
                }

                if let profile = defaultProfile {
                    LabeledContent("Model") {
                        Text(profile.defaultModel)
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

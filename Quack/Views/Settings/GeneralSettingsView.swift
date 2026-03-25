import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(ProviderService.self) private var providerService
    @Query(sort: \Provider.sortOrder) private var providers: [Provider]

    @AppStorage("defaultSystemPrompt") private var defaultSystemPrompt = ""

    var body: some View {
        Form {
            defaultProviderSection
            systemPromptSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Default Provider

    @MainActor
    private var defaultProviderSection: some View {
        Section(content: {
            Picker("Provider", selection: Binding(
                get: { providerService.defaultProviderID },
                set: { providerService.defaultProviderID = $0 }
            )) {
                Text("None").tag(nil as UUID?)
                Divider()
                ForEach(providers.filter(\.isEnabled)) { provider in
                    Text("\(provider.name) (\(provider.defaultModel))")
                        .tag(provider.id as UUID?)
                }
            }

        }, header: {
            Text("Default Provider")
            Text("New chats will use this provider and its default model.")
        })
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        Section(content: {
            TextEditor(text: $defaultSystemPrompt)
                .font(.body.monospaced())
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
        }, header: {
            Text("Default System Prompt")
            Text("Applied to new chats unless overridden in the chat inspector.")
        })
    }
}

#Preview {
    let container = PreviewSupport.container
    let _ = PreviewSupport.seed(container)

    GeneralSettingsView()
        .previewEnvironment(container: container)
        .frame(width: 500, height: 400)
}

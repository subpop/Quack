import SwiftUI
import SwiftData

@main
struct QuackApp: App {
    @State private var providerService = ProviderService()
    @State private var chatService = ChatService()
    @State private var mcpService = MCPService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatSession.self,
            ChatMessageRecord.self,
            Provider.self,
            MCPServerConfig.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
                .modelContainer(sharedModelContainer)
        }
    }
}

extension Notification.Name {
    static let newChat = Notification.Name("newChat")
}

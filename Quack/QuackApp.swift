import SwiftUI
import SwiftData

@main
struct QuackApp: App {
    @State private var providerService = ProviderService()
    @State private var chatService = ChatService()
    @State private var mcpService = MCPService()
    @State private var modelListService = ModelListService()

    @Environment(\.openWindow) private var openWindow

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatSession.self,
            ChatMessageRecord.self,
            ProviderProfile.self,
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
        WindowGroup(id: "main") {
            MainView()
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
                .environment(modelListService)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            SidebarCommands()
            CommandGroup(after: .singleWindowList) {
                Button("Quack", systemImage: "macwindow") {
                    if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                        NSApplication.shared.activate()
                    } else {
                        openWindow(id: "main")
                    }
                }
                .keyboardShortcut("0")
            }
        }

        Settings {
            SettingsView()
                .environment(providerService)
                .environment(chatService)
                .environment(mcpService)
                .environment(modelListService)
                .modelContainer(sharedModelContainer)
        }
    }
}

extension Notification.Name {
    static let newChat = Notification.Name("newChat")
}

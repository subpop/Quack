import SwiftUI
import SwiftData
import os

@main
struct QuackApp: App {
    @StateObject private var updater = SoftwareUpdater()

    @State private var providerService = ProviderService()
    @State private var chatService = ChatService()
    @State private var mcpService = MCPService()
    @State private var modelListService = ModelListService()

    @Environment(\.openWindow) private var openWindow

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: ChatSession.self, ChatMessageRecord.self,
                     ProviderProfile.self, MCPServerConfig.self,
                     Assistant.self,
                migrationPlan: QuackMigrationPlan.self
            )
        } catch {
            Logger.database.error(
                "Failed to create persistent ModelContainer, falling back to in-memory store: \(error)"
            )
            do {
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: ChatSession.self, ChatMessageRecord.self,
                         ProviderProfile.self, MCPServerConfig.self,
                         Assistant.self,
                    configurations: fallbackConfig
                )
            } catch {
                fatalError("Cannot create even an in-memory ModelContainer: \(error)")
            }
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
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
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
            SettingsView(updater: updater)
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

extension Logger {
    static let database = Logger(subsystem: "com.quack.app", category: "database")
}

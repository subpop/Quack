import Testing
import Foundation
@testable import QuackKit

struct BuiltInToolServiceTests {
    @Test @MainActor func initWithSettingsURL() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        let service = BuiltInToolService(settingsURL: tmpURL)
        #expect(!service.enabledTools.isEmpty)
        do { try? FileManager.default.removeItem(at: tmpURL) }
    }

    @Test @MainActor func setEnabledToggle() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let service = BuiltInToolService(settingsURL: tmpURL)
        #expect(service.isEnabled(.readFile) == true)

        service.setEnabled(false, for: .readFile)
        #expect(service.isEnabled(.readFile) == false)

        service.setEnabled(true, for: .readFile)
        #expect(service.isEnabled(.readFile) == true)
    }

    @Test @MainActor func defaultPermission() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let service = BuiltInToolService(settingsURL: tmpURL)
        #expect(service.defaultPermission(for: .readFile) == .ask)
        #expect(service.defaultPermission(for: .writeFile) == .ask)
    }

    @Test @MainActor func setDefaultPermission() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let service = BuiltInToolService(settingsURL: tmpURL)
        service.setDefaultPermission(.always, for: .readFile)
        #expect(service.defaultPermission(for: .readFile) == .always)
    }

    @Test @MainActor func enabledToolSummaries() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let service = BuiltInToolService(settingsURL: tmpURL)
        let summaries = service.enabledToolSummaries
        #expect(!summaries.isEmpty)
        #expect(summaries.contains(where: { $0.name == "builtin-read_file" }))
    }

    @Test @MainActor func persistenceRoundTrip() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_builtin_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let service1 = BuiltInToolService(settingsURL: tmpURL)
        service1.setEnabled(false, for: .readFile)
        service1.setDefaultPermission(.always, for: .writeFile)

        let service2 = BuiltInToolService(settingsURL: tmpURL)
        #expect(service2.isEnabled(.readFile) == false)
        #expect(service2.defaultPermission(for: .writeFile) == .always)
    }
}

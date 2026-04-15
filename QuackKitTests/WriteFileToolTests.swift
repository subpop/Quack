import Testing
import Foundation
@testable import QuackKit

struct WriteFileToolTests {
    @Test func toolMetadata() {
        let tool = WriteFileTool()
        #expect(tool.name == "builtin-write_file")
        #expect(tool.description == "Write content to a file at a given path.")
    }

    @Test func writeNewFile() async throws {
        let tool = WriteFileTool()
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("quack_write_test_\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let args = try JSONEncoder().encode(["path": tmpFile.path, "content": "Test content"])
        let result = try await tool.execute(arguments: args, context: EmptyContext())
        #expect(result.isError == false)
        #expect(result.content.contains("Successfully wrote"))

        let contents = try String(contentsOf: tmpFile, encoding: .utf8)
        #expect(contents == "Test content")
    }

    @Test func writeCreatesParentDirectories() async throws {
        let tool = WriteFileTool()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("quack_test_\(UUID().uuidString)")
            .appendingPathComponent("nested")
        let tmpFile = tmpDir.appendingPathComponent("file.txt")
        defer { try? FileManager.default.removeItem(at: tmpDir.deletingLastPathComponent()) }

        let args = try JSONEncoder().encode(["path": tmpFile.path, "content": "nested content"])
        let result = try await tool.execute(arguments: args, context: EmptyContext())
        #expect(result.isError == false)

        let contents = try String(contentsOf: tmpFile, encoding: .utf8)
        #expect(contents == "nested content")
    }

    @Test func writeInvalidArguments() async throws {
        let tool = WriteFileTool()
        let result = try await tool.execute(arguments: Data("{}".utf8), context: EmptyContext())
        #expect(result.isError == true)
        #expect(result.content.contains("Invalid arguments"))
    }
}

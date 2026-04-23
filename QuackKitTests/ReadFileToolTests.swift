import Testing
import Foundation
@testable import QuackKit

struct ReadFileToolTests {
    @Test func toolMetadata() {
        let tool = ReadFileTool()
        #expect(tool.name == "builtin-read_file")
        #expect(tool.description == "Read the contents of a file at a given path.")
    }

    @Test func readExistingFile() async throws {
        let tool = ReadFileTool()
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("quack_test_\(UUID().uuidString).txt")
        try "Hello, QuackKit!".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let args = try JSONEncoder().encode(["path": tmpFile.path])
        let result = try await tool.execute(arguments: args, context: QuackToolContext())
        #expect(result.content == "Hello, QuackKit!")
        #expect(result.isError == false)
    }

    @Test func readNonexistentFile() async throws {
        let tool = ReadFileTool()
        let args = try JSONEncoder().encode(["path": "/nonexistent/path/file.txt"])
        let result = try await tool.execute(arguments: args, context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("not found"))
    }

    @Test func readInvalidArguments() async throws {
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: Data("{}".utf8), context: QuackToolContext())
        #expect(result.isError == true)
        #expect(result.content.contains("Invalid arguments"))
    }
}

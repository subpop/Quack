import Testing
import Foundation
@testable import QuackKit

struct BuiltInToolTests {
    @Test func rawValues() {
        #expect(BuiltInTool.readFile.rawValue == "builtin-read_file")
        #expect(BuiltInTool.writeFile.rawValue == "builtin-write_file")
        #expect(BuiltInTool.runCommand.rawValue == "builtin-run_command")
        #expect(BuiltInTool.webFetch.rawValue == "builtin-web_fetch")
        #expect(BuiltInTool.webSearch.rawValue == "builtin-web_search")
    }

    @Test func identifiers() {
        for tool in BuiltInTool.allCases {
            #expect(tool.id == tool.rawValue)
        }
    }

    @Test func displayNames() {
        #expect(BuiltInTool.readFile.displayName == "Read File")
        #expect(BuiltInTool.writeFile.displayName == "Write File")
        #expect(BuiltInTool.runCommand.displayName == "Run Command")
        #expect(BuiltInTool.webFetch.displayName == "Web Fetch")
        #expect(BuiltInTool.webSearch.displayName == "Web Search")
    }

    @Test func toolDescriptions() {
        for tool in BuiltInTool.allCases {
            #expect(!tool.toolDescription.isEmpty)
        }
    }

    @Test func iconNames() {
        #expect(BuiltInTool.readFile.iconName == "doc.text")
        #expect(BuiltInTool.writeFile.iconName == "square.and.pencil")
        #expect(BuiltInTool.runCommand.iconName == "terminal")
        #expect(BuiltInTool.webFetch.iconName == "globe")
        #expect(BuiltInTool.webSearch.iconName == "magnifyingglass")
    }

    @Test func requiresBuildTimeKey() {
        #expect(BuiltInTool.readFile.requiresBuildTimeKey == false)
        #expect(BuiltInTool.writeFile.requiresBuildTimeKey == false)
        #expect(BuiltInTool.runCommand.requiresBuildTimeKey == false)
        #expect(BuiltInTool.webFetch.requiresBuildTimeKey == false)
        #expect(BuiltInTool.webSearch.requiresBuildTimeKey == true)
    }

    @Test func allCasesCount() {
        #expect(BuiltInTool.allCases.count == 5)
    }

    @Test func codableRoundTrip() throws {
        for tool in BuiltInTool.allCases {
            let data = try JSONEncoder().encode(tool)
            let decoded = try JSONDecoder().decode(BuiltInTool.self, from: data)
            #expect(decoded == tool)
        }
    }

    @Test func buildTimeKeyForNonSearchTools() {
        #expect(BuiltInTool.readFile.buildTimeKey == nil)
        #expect(BuiltInTool.writeFile.buildTimeKey == nil)
        #expect(BuiltInTool.runCommand.buildTimeKey == nil)
        #expect(BuiltInTool.webFetch.buildTimeKey == nil)
    }
}

import Foundation
import AgentRunKit

extension JSONValue {
    /// Parse a raw JSON string into a `JSONValue`.
    static func parse(_ jsonString: String) -> JSONValue? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Pretty-print the value as a JSON string.
    func prettyPrinted() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "\(self)"
        }
        return string
    }
}

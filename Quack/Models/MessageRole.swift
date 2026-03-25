import Foundation

enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

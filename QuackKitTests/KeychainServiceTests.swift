import Testing
import Foundation
@testable import QuackKit

struct KeychainServiceTests {
    @Test func apiKeyKeyFormat() {
        let uuid = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let key = KeychainService.apiKeyKey(for: uuid)
        #expect(key == "apikey.12345678-1234-1234-1234-123456789ABC")
    }

    @Test func apiKeyKeyUniqueness() {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let key1 = KeychainService.apiKeyKey(for: uuid1)
        let key2 = KeychainService.apiKeyKey(for: uuid2)
        #expect(key1 != key2)
    }
}

import Testing
import Foundation
@testable import QuackKit

struct KeychainErrorTests {
    @Test func errorDescription() {
        let error = KeychainError.saveFailed(-25299)
        #expect(error.errorDescription?.contains("-25299") == true)
        #expect(error.errorDescription?.contains("Keychain") == true)
    }
}

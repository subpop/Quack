import Testing
import Foundation
@testable import QuackKit

struct StubMLXModelServiceTests {
    @Test @MainActor func stubDefaults() {
        let stub = StubMLXModelService()
        if case .idle = stub.loadState {} else { Issue.record("Expected idle") }
        #expect(stub.loadedModelID == nil)
        #expect(stub.downloadedModels.isEmpty)
        #expect(stub.cachedContainerAsAny(for: "any") == nil)
    }

    @Test @MainActor func stubOperationsDoNotCrash() {
        let stub = StubMLXModelService()
        stub.unloadModel()
        stub.scanDownloadedModels()
    }
}

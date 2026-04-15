import Testing
import Foundation
@testable import QuackKit

struct DownloadedMLXModelTests {
    @Test func shortNameWithOrg() {
        let model = DownloadedMLXModel(
            id: "mlx-community/Qwen3-8B-4bit",
            sizeOnDisk: 1_000_000,
            url: URL(fileURLWithPath: "/tmp/model")
        )
        #expect(model.shortName == "Qwen3-8B-4bit")
    }

    @Test func shortNameWithoutOrg() {
        let model = DownloadedMLXModel(
            id: "standalone-model",
            sizeOnDisk: 1_000_000,
            url: URL(fileURLWithPath: "/tmp/model")
        )
        #expect(model.shortName == "standalone-model")
    }

    @Test func formattedSize() {
        let model = DownloadedMLXModel(
            id: "test/model",
            sizeOnDisk: 3_200_000_000,
            url: URL(fileURLWithPath: "/tmp/model")
        )
        let formatted = model.formattedSize
        #expect(!formatted.isEmpty)
    }

    @Test func identifiable() {
        let model = DownloadedMLXModel(
            id: "org/model-name",
            sizeOnDisk: 100,
            url: URL(fileURLWithPath: "/tmp")
        )
        #expect(model.id == "org/model-name")
    }
}

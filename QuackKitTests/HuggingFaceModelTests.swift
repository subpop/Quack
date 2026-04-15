import Testing
import Foundation
@testable import QuackKit

struct HuggingFaceModelTests {
    private func makeModel(id: String, downloads: Int = 0, likes: Int = 0, tags: [String] = []) -> HuggingFaceAPI.Model {
        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ",")
        let json = """
        {"id":"\(id)","downloads":\(downloads),"likes":\(likes),"tags":[\(tagsJSON)]}
        """
        return try! JSONDecoder().decode(HuggingFaceAPI.Model.self, from: Data(json.utf8))
    }

    @Test func shortNameWithOrg() {
        let model = makeModel(id: "mlx-community/Llama-3.2-3B-Instruct-4bit")
        #expect(model.shortName == "Llama-3.2-3B-Instruct-4bit")
    }

    @Test func shortNameWithoutOrg() {
        let model = makeModel(id: "standalone")
        #expect(model.shortName == "standalone")
    }

    @Test func quantizationFromTags() {
        let model = makeModel(id: "org/model", tags: ["mlx", "4-bit", "text-generation"])
        #expect(model.quantization == "4-bit")
    }

    @Test func quantizationBf16() {
        let model = makeModel(id: "org/model", tags: ["mlx", "bf16"])
        #expect(model.quantization == "bf16")
    }

    @Test func quantizationFp16() {
        let model = makeModel(id: "org/model", tags: ["mlx", "fp16"])
        #expect(model.quantization == "fp16")
    }

    @Test func quantizationNone() {
        let model = makeModel(id: "org/model", tags: ["mlx", "text-generation"])
        #expect(model.quantization == nil)
    }

    @Test func formattedDownloadsMillions() {
        let model = makeModel(id: "org/model", downloads: 1_500_000)
        #expect(model.formattedDownloads == "1.5M")
    }

    @Test func formattedDownloadsThousands() {
        let model = makeModel(id: "org/model", downloads: 45_000)
        #expect(model.formattedDownloads == "45K")
    }

    @Test func formattedDownloadsSmall() {
        let model = makeModel(id: "org/model", downloads: 89)
        #expect(model.formattedDownloads == "89")
    }

    @Test func identifiable() {
        let model = makeModel(id: "org/model-name")
        #expect(model.id == "org/model-name")
    }
}

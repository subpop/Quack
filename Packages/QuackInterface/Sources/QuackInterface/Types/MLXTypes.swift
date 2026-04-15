// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftUI

// MARK: - Shared Types

/// The current state of an MLX model load operation.
///
/// This enum is defined independently of the MLX framework so it can
/// be used in SwiftUI views without pulling in Metal-dependent code.
public enum MLXLoadState: Sendable {
    /// No model is loaded or loading.
    case idle
    /// Downloading model weights from HuggingFace Hub.
    case downloading(progress: Double)
    /// Weights downloaded; loading model into GPU memory.
    case loading
    /// Model is loaded and ready for inference.
    case ready
    /// Loading failed with an error message.
    case failed(String)
}

/// A model that has been downloaded to the local HuggingFace Hub cache.
///
/// This struct is defined independently of the MLX framework so it can
/// be used in SwiftUI views without pulling in Metal-dependent code.
public struct DownloadedMLXModel: Identifiable, Sendable {
    /// The HuggingFace model identifier (e.g. `"mlx-community/Qwen3-8B-4bit"`).
    public let id: String
    /// The size of the model on disk, in bytes.
    public let sizeOnDisk: UInt64
    /// The directory URL where the model is stored.
    public let url: URL

    public init(id: String, sizeOnDisk: UInt64, url: URL) {
        self.id = id
        self.sizeOnDisk = sizeOnDisk
        self.url = url
    }

    /// Display name without the org prefix.
    public var shortName: String {
        if let slashIndex = id.firstIndex(of: "/") {
            return String(id[id.index(after: slashIndex)...])
        }
        return id
    }

    /// Human-readable size string (e.g. "3.2 GB", "743 MB").
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeOnDisk), countStyle: .file)
    }
}

// MARK: - Protocol

/// Abstraction for MLX model management that decouples views from the
/// Metal-dependent MLX framework.
///
/// The real implementation (`MLXModelService`) imports `MLXLLM`, `MLXLMCommon`,
/// and `Hub`, which transitively depend on `mlx-swift` — a library whose
/// C/Metal code is incompatible with Xcode's XOJIT preview JIT linker.
/// By programming views against this protocol (via ``MLXModelServiceBox``),
/// previews can use a lightweight stub that never loads any MLX code.
@MainActor
public protocol MLXModelProviding: AnyObject {
    /// The current load state, observable by SwiftUI views.
    var loadState: MLXLoadState { get }

    /// The HuggingFace model identifier currently loaded (or being loaded).
    var loadedModelID: String? { get }

    /// Downloaded models discovered on disk, observable by SwiftUI views.
    var downloadedModels: [DownloadedMLXModel] { get }

    /// Load a model by its HuggingFace identifier.
    func loadModel(id: String) async throws

    /// Unload the current model, freeing GPU memory.
    func unloadModel()

    /// Scan the HuggingFace Hub cache directory for downloaded MLX models.
    func scanDownloadedModels()

    /// Delete a downloaded model from the local cache.
    func deleteDownloadedModel(_ model: DownloadedMLXModel)

    /// Returns the cached model container as a type-erased value, or `nil`
    /// if the given model is not currently loaded. The returned value is an
    /// `MLXLMCommon.ModelContainer` at runtime, but is erased to `Any` here
    /// to avoid importing Metal-dependent frameworks.
    func cachedContainerAsAny(for modelID: String) -> Any?
}

// MARK: - Type-Erased Box

/// Concrete `@Observable` wrapper around an ``MLXModelProviding`` conformer.
///
/// SwiftUI's `@Environment` requires a concrete type, so views use this
/// box instead of the protocol directly. At app startup, ``QuackApp``
/// injects a box wrapping the real `MLXModelService`; in previews,
/// ``PreviewSupport`` injects a box wrapping ``StubMLXModelService``.
@Observable
@MainActor
public final class MLXModelServiceBox {
    public let service: any MLXModelProviding

    public init(service: any MLXModelProviding) {
        self.service = service
    }

    public var loadState: MLXLoadState { service.loadState }
    public var loadedModelID: String? { service.loadedModelID }
    public var downloadedModels: [DownloadedMLXModel] { service.downloadedModels }

    public func loadModel(id: String) async throws { try await service.loadModel(id: id) }
    public func unloadModel() { service.unloadModel() }
    public func scanDownloadedModels() { service.scanDownloadedModels() }
    public func deleteDownloadedModel(_ model: DownloadedMLXModel) { service.deleteDownloadedModel(model) }
    public func cachedContainerAsAny(for modelID: String) -> Any? { service.cachedContainerAsAny(for: modelID) }
}

// MARK: - Environment Key

private struct MLXModelServiceBoxKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: MLXModelServiceBox = MLXModelServiceBox(service: StubMLXModelService())
}

public extension EnvironmentValues {
    var mlxModelServiceBox: MLXModelServiceBox {
        get { self[MLXModelServiceBoxKey.self] }
        set { self[MLXModelServiceBoxKey.self] = newValue }
    }
}

// MARK: - Downloaded Model Discovery (MLX-Free)

/// Scans the HuggingFace Hub cache directory for downloaded model IDs
/// using only Foundation APIs, without importing any MLX framework.
///
/// The Hub library stores models at `<Caches>/models/<org>/<model>/`.
/// This function replicates that directory walk.
public func mlxDownloadedModelIDsFromDisk() -> [String] {
    guard let cachesDir = FileManager.default.urls(
        for: .cachesDirectory, in: .userDomainMask
    ).first else { return [] }

    let modelsDir = cachesDir.appendingPathComponent("models")
    let fm = FileManager.default

    guard fm.fileExists(atPath: modelsDir.path) else { return [] }

    var ids: [String] = []

    guard let orgDirs = try? fm.contentsOfDirectory(
        at: modelsDir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    for orgDir in orgDirs {
        guard let isDir = try? orgDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
              isDir else { continue }

        let orgName = orgDir.lastPathComponent

        guard let modelDirs = try? fm.contentsOfDirectory(
            at: orgDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { continue }

        for modelDir in modelDirs {
            guard let isModelDir = try? modelDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isModelDir else { continue }

            let configPath = modelDir.appendingPathComponent("config.json")
            guard fm.fileExists(atPath: configPath.path) else { continue }

            ids.append("\(orgName)/\(modelDir.lastPathComponent)")
        }
    }

    return ids.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

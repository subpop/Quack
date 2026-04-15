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
import Hub
import MLXLMCommon
import MLXLLM
import os
import QuackInterface

/// Manages the lifecycle of MLX on-device models: downloading, loading,
/// caching, and unloading.
///
/// Only one model is kept in memory at a time. If a different model is
/// requested, the current one is unloaded first. Download progress and
/// loading state are published for UI binding.
///
/// Conforms to ``MLXModelProviding`` so that views interact with it
/// through ``MLXModelServiceBox`` without importing any MLX frameworks.
@Observable
@MainActor
public final class MLXModelService: MLXModelProviding {

    /// The current load state, observable by SwiftUI views.
    public private(set) var loadState: MLXLoadState = .idle

    /// The HuggingFace model identifier currently loaded (or being loaded).
    public private(set) var loadedModelID: String?

    /// The loaded model container, ready for use by `MLXClientFactory`.
    public private(set) var container: ModelContainer?

    /// In-flight loading task, used to cancel if a new load is requested.
    private var loadTask: Task<ModelContainer, Error>?

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.subpop.Quack",
        category: "MLXModelService"
    )

    // MARK: - Init

    public init() {}

    // MARK: - MLXModelProviding

    /// Load a model by its HuggingFace identifier.
    ///
    /// If the requested model is already loaded, returns immediately.
    /// If a different model is loaded, unloads it first. Tracks download
    /// and loading progress via `loadState`.
    ///
    /// - Parameter id: HuggingFace model identifier, e.g. `"mlx-community/Qwen3-8B-4bit"`.
    /// - Throws: If the download or model loading fails.
    public func loadModel(id: String) async throws {
        // Already loaded — return cached container.
        if container != nil, loadedModelID == id {
            loadState = .ready
            return
        }

        // Cancel any in-flight load for a different model.
        loadTask?.cancel()
        loadTask = nil

        // Unload previous model to free GPU memory.
        if container != nil {
            unloadModel()
        }

        loadedModelID = id
        loadState = .downloading(progress: 0)

        Self.logger.info("Loading MLX model: \(id)")

        let modelID = id

        // Use a stream to forward download progress from the @Sendable
        // progress handler back to the @MainActor context.
        let (progressStream, progressContinuation) = AsyncStream<Double>.makeStream()

        let task = Task<ModelContainer, Error> {
            let configuration = ModelConfiguration(id: modelID)

            let loaded = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { @Sendable progress in
                progressContinuation.yield(progress.fractionCompleted)
            }

            progressContinuation.finish()
            try Task.checkCancellation()
            return loaded
        }

        // Monitor progress updates on the main actor.
        let progressTask = Task {
            for await fraction in progressStream {
                guard loadedModelID == modelID else { break }
                loadState = .downloading(progress: fraction)
            }
        }

        loadTask = task

        do {
            let loaded = try await task.value
            progressTask.cancel()
            container = loaded
            loadState = .ready
            Self.logger.info("MLX model loaded: \(id)")
        } catch is CancellationError {
            progressTask.cancel()
            Self.logger.info("MLX model load cancelled: \(id)")
            throw CancellationError()
        } catch {
            progressTask.cancel()
            loadState = .failed(error.localizedDescription)
            loadedModelID = nil
            Self.logger.error("MLX model load failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Returns the cached container if the given model is already loaded.
    public func cachedContainer(for modelID: String) -> ModelContainer? {
        guard loadedModelID == modelID else { return nil }
        return container
    }

    public func cachedContainerAsAny(for modelID: String) -> Any? {
        cachedContainer(for: modelID)
    }

    /// Unload the current model, freeing GPU memory.
    public func unloadModel() {
        loadTask?.cancel()
        loadTask = nil
        container = nil
        loadedModelID = nil
        loadState = .idle
        Self.logger.info("MLX model unloaded")
    }

    // MARK: - Downloaded Model Discovery

    /// Downloaded models discovered on disk, observable by SwiftUI views.
    public private(set) var downloadedModels: [DownloadedMLXModel] = []

    /// Scan the HuggingFace Hub cache directory for downloaded MLX models.
    ///
    /// The cache location is derived from `defaultHubApi` (defined by mlx-swift-lm),
    /// which stores models at `<downloadBase>/models/<org>/<model-name>/`.
    /// By default on macOS this is `~/Library/Caches/models/`.
    public func scanDownloadedModels() {
        let models = Self.scanCache()
        downloadedModels = models
        Self.logger.info("Found \(models.count) downloaded model(s)")
    }

    /// Returns the HuggingFace model IDs of all locally downloaded models.
    ///
    /// This is a lightweight, static method suitable for use from contexts
    /// that don't have access to an `MLXModelService` instance (e.g.
    /// `ProviderPlatform.listModels`). It only scans directory names and
    /// checks for `config.json` existence — it does not calculate sizes.
    public static func downloadedModelIDs() -> [String] {
        let modelsDir = defaultHubApi.localRepoLocation(Hub.Repo(id: ""))
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

    // MARK: - Private Cache Scan

    /// Full cache scan that returns `DownloadedMLXModel` entries with size info.
    private static func scanCache() -> [DownloadedMLXModel] {
        let modelsDir = defaultHubApi.localRepoLocation(Hub.Repo(id: ""))
        let fm = FileManager.default

        guard fm.fileExists(atPath: modelsDir.path) else { return [] }

        var found: [DownloadedMLXModel] = []

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

                let modelName = modelDir.lastPathComponent
                let modelID = "\(orgName)/\(modelName)"

                let configPath = modelDir.appendingPathComponent("config.json")
                guard fm.fileExists(atPath: configPath.path) else { continue }

                let size = directorySize(at: modelDir)

                found.append(DownloadedMLXModel(
                    id: modelID,
                    sizeOnDisk: size,
                    url: modelDir
                ))
            }
        }

        return found.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    /// Delete a downloaded model from the local cache.
    ///
    /// If the model is currently loaded, it will be unloaded first.
    public func deleteDownloadedModel(_ model: DownloadedMLXModel) {
        if loadedModelID == model.id {
            unloadModel()
        }

        do {
            try FileManager.default.removeItem(at: model.url)
            Self.logger.info("Deleted model: \(model.id)")
        } catch {
            Self.logger.error("Failed to delete model \(model.id): \(error.localizedDescription)")
        }

        // Re-scan to update the list
        scanDownloadedModels()
    }

    // MARK: - Private Helpers

    /// Recursively calculates the total size of a directory in bytes.
    private static func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory == false,
                  let size = values.fileSize else { continue }
            total += UInt64(size)
        }
        return total
    }
}

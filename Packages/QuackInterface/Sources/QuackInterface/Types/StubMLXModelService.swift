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

/// Lightweight stub conforming to ``MLXModelProviding`` for use in
/// SwiftUI previews.
///
/// This class does not import any MLX frameworks, so it can be loaded
/// by the Xcode XOJIT preview JIT linker without triggering the
/// Metal/C++ code that causes preview crashes.
@Observable
@MainActor
public final class StubMLXModelService: MLXModelProviding {

    public private(set) var loadState: MLXLoadState = .idle
    public private(set) var loadedModelID: String? = nil
    public private(set) var downloadedModels: [DownloadedMLXModel] = []

    public init() {}

    public func loadModel(id: String) async throws {
        // No-op in preview stub
    }

    public func unloadModel() {
        // No-op in preview stub
    }

    public func scanDownloadedModels() {
        // No-op in preview stub
    }

    public func deleteDownloadedModel(_ model: DownloadedMLXModel) {
        // No-op in preview stub
    }

    public func cachedContainerAsAny(for modelID: String) -> Any? {
        nil
    }
}

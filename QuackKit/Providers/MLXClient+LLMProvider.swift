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
import AgentRunKit
import AgentRunKitMLX
import MLXLMCommon
import QuackInterface

/// Factory utilities for MLX on-device inference.
///
/// Used by `ProviderPlatform.mlx` to construct clients. Requires a pre-loaded
/// `ModelContainer` obtained from `MLXModelService`. Returns `nil` if no
/// container is available (model not yet loaded).
public enum MLXClientFactory {

    public static func makeClient(
        container: ModelContainer?,
        model: String?,
        maxTokens: Int,
        contextWindowSize: Int?
    ) -> (any LLMClient)? {
        guard let container else { return nil }

        var parameters = GenerateParameters()
        parameters.maxTokens = maxTokens

        return MLXClient(
            container: container,
            model: model,
            contextWindowSize: contextWindowSize,
            parameters: parameters
        )
    }
}

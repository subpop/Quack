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
import AgentRunKitFoundationModels

/// Factory utilities for Apple Foundation Models (on-device inference).
///
/// Used by `ProviderPlatform.foundationModels` to construct clients.
/// No model listing is needed — the on-device model is the only option.
enum FoundationModelsClientFactory {

    static func makeClient() -> (any LLMClient)? {
        return FoundationModelsClient<EmptyContext>(
            tools: [] as [any AnyTool<EmptyContext>],
            context: EmptyContext()
        )
    }
}

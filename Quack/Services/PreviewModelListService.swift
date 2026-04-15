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

import Observation
import QuackInterface

/// A minimal ``ModelListServiceProtocol`` implementation for SwiftUI previews.
///
/// Returns the platform's built-in known models as a fallback, matching
/// the behavior of the real service before any API fetch has completed.
@Observable
@MainActor
final class PreviewModelListService: ModelListServiceProtocol {
    func isLoading(for profile: ProviderProfile) -> Bool { false }
    func models(for profile: ProviderProfile) -> [String] { profile.platform.knownModels }
    func fetchModels(for profile: ProviderProfile) async {}
    func invalidate(for profile: ProviderProfile) {}
    func invalidateAll() {}
}

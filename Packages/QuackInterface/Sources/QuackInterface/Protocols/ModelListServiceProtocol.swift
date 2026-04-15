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

// MARK: - Protocol

@MainActor
public protocol ModelListServiceProtocol: AnyObject, Observable {
    /// Whether models are currently being fetched for a profile.
    func isLoading(for profile: ProviderProfile) -> Bool

    /// Returns the cached or fallback model list for the given profile.
    func models(for profile: ProviderProfile) -> [String]

    /// Fetches models from the provider's API, caching the result.
    func fetchModels(for profile: ProviderProfile) async

    /// Removes the cached model list for a profile, forcing a re-fetch.
    func invalidate(for profile: ProviderProfile)

    /// Removes all cached model lists.
    func invalidateAll()
}

// MARK: - Environment Key

private struct ModelListServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ModelListServiceProtocol = PlaceholderModelListService()
}

public extension EnvironmentValues {
    var modelListService: any ModelListServiceProtocol {
        get { self[ModelListServiceKey.self] }
        set { self[ModelListServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderModelListService: ModelListServiceProtocol {
    func isLoading(for profile: ProviderProfile) -> Bool { false }
    func models(for profile: ProviderProfile) -> [String] { [] }
    func fetchModels(for profile: ProviderProfile) async {}
    func invalidate(for profile: ProviderProfile) {}
    func invalidateAll() {}
}

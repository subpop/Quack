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
public protocol ProviderServiceProtocol: AnyObject, Observable {
    /// The current MLX load state, forwarded from the model service.
    /// Returns `.idle` if no MLX model service is configured.
    var mlxLoadState: MLXLoadState { get }

    /// Resolve the effective ProviderProfile for a chat session,
    /// falling back to the first enabled profile.
    func resolvedProfile(for session: ChatSession, profiles: [ProviderProfile]) -> ProviderProfile?

    /// Resolve the effective model identifier for a chat session.
    func resolvedModel(for session: ChatSession, profiles: [ProviderProfile]) -> String

    /// Fallback profile when the session has no provider set.
    func fallbackProfile(from profiles: [ProviderProfile]) -> ProviderProfile?

    /// Clear the client cache.
    func invalidateCache()
}

// MARK: - Environment Key

private struct ProviderServiceKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ProviderServiceProtocol = PlaceholderProviderService()
}

public extension EnvironmentValues {
    var providerService: any ProviderServiceProtocol {
        get { self[ProviderServiceKey.self] }
        set { self[ProviderServiceKey.self] = newValue }
    }
}

// MARK: - Placeholder

@Observable
@MainActor
private final class PlaceholderProviderService: ProviderServiceProtocol {
    var mlxLoadState: MLXLoadState = .idle

    func resolvedProfile(for session: ChatSession, profiles: [ProviderProfile]) -> ProviderProfile? { nil }
    func resolvedModel(for session: ChatSession, profiles: [ProviderProfile]) -> String { "unknown" }
    func fallbackProfile(from profiles: [ProviderProfile]) -> ProviderProfile? { nil }
    func invalidateCache() {}
}

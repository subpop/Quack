import Foundation

/// Fetches, caches, and provides model lists for each provider.
///
/// On first access for a given provider, the service attempts to query the
/// provider's API via `LLMProvider.listModels(for:)`. If the API call succeeds
/// and returns a non-empty list, the result is cached. Otherwise, the service
/// falls back to the static `ProviderKind.knownModels` list.
///
/// The cache is keyed by `Provider.id` and is invalidated when the provider's
/// configuration changes (e.g., URL or API key).
@Observable
@MainActor
final class ModelListService {
    // MARK: - Cache Entry

    private struct CacheEntry {
        let models: [String]
        let fetchedAt: Date
    }

    // MARK: - State

    private var cache: [UUID: CacheEntry] = [:]
    private var inFlight: Set<UUID> = []

    /// Whether models are currently being fetched for a provider.
    func isLoading(for provider: Provider) -> Bool {
        inFlight.contains(provider.id)
    }

    /// Returns the cached or fallback model list for the given provider.
    ///
    /// If models haven't been fetched yet, returns `ProviderKind.knownModels`
    /// as a synchronous fallback. Call `fetchModels(for:)` to trigger an
    /// asynchronous API query.
    func models(for provider: Provider) -> [String] {
        if let entry = cache[provider.id] {
            return entry.models
        }
        return provider.kind.knownModels
    }

    /// Fetches models from the provider's API, caching the result.
    ///
    /// If the API returns an empty list or throws, falls back to
    /// `ProviderKind.knownModels`. Safe to call multiple times --
    /// concurrent requests for the same provider are coalesced.
    func fetchModels(for provider: Provider) async {
        guard !inFlight.contains(provider.id) else { return }

        inFlight.insert(provider.id)
        defer { inFlight.remove(provider.id) }

        do {
            let fetched = try await provider.kind.providerType.listModels(for: provider)
            if fetched.isEmpty {
                cache[provider.id] = CacheEntry(
                    models: provider.kind.knownModels,
                    fetchedAt: Date()
                )
            } else {
                cache[provider.id] = CacheEntry(
                    models: fetched,
                    fetchedAt: Date()
                )
            }
        } catch {
            // Network failure — fall back to known models
            cache[provider.id] = CacheEntry(
                models: provider.kind.knownModels,
                fetchedAt: Date()
            )
        }
    }

    /// Removes the cached model list for a provider, forcing a re-fetch
    /// on the next call to `fetchModels(for:)`.
    func invalidate(for provider: Provider) {
        cache.removeValue(forKey: provider.id)
    }

    /// Removes all cached model lists.
    func invalidateAll() {
        cache.removeAll()
    }
}

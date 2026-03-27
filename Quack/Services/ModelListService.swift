import Foundation

/// Fetches, caches, and provides model lists for each provider profile.
///
/// On first access for a given profile, the service attempts to query the
/// provider's API via `ProviderPlatform.listModels(...)`. If the API call
/// succeeds and returns a non-empty list, the result is cached. Otherwise,
/// the service falls back to `ProviderPlatform.knownModels`.
///
/// The cache is keyed by `ProviderProfile.id` and is invalidated when the
/// profile's configuration changes (e.g., URL or API key).
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

    /// Whether models are currently being fetched for a profile.
    func isLoading(for profile: ProviderProfile) -> Bool {
        inFlight.contains(profile.id)
    }

    /// Returns the cached or fallback model list for the given profile.
    ///
    /// If models haven't been fetched yet, returns `ProviderPlatform.knownModels`
    /// as a synchronous fallback. Call `fetchModels(for:)` to trigger an
    /// asynchronous API query.
    func models(for profile: ProviderProfile) -> [String] {
        if let entry = cache[profile.id] {
            return entry.models
        }
        return profile.platform.knownModels
    }

    /// Fetches models from the provider's API, caching the result.
    ///
    /// If the API returns an empty list or throws, falls back to
    /// `ProviderPlatform.knownModels`. Safe to call multiple times --
    /// concurrent requests for the same profile are coalesced.
    func fetchModels(for profile: ProviderProfile) async {
        guard !inFlight.contains(profile.id) else { return }

        inFlight.insert(profile.id)
        defer { inFlight.remove(profile.id) }

        // Resolve connection details for the listModels call
        let baseURL: URL? = {
            guard let urlString = profile.baseURL else { return nil }
            return URL(string: urlString)
        }()
        let apiKey: String? = profile.requiresAPIKey
            ? KeychainService.load(key: KeychainService.apiKeyKey(for: profile.id))
            : nil

        do {
            let fetched = try await profile.platform.listModels(
                baseURL: baseURL,
                apiKey: apiKey,
                projectID: profile.projectID,
                location: profile.location
            )
            if fetched.isEmpty {
                cache[profile.id] = CacheEntry(
                    models: profile.platform.knownModels,
                    fetchedAt: Date()
                )
            } else {
                cache[profile.id] = CacheEntry(
                    models: fetched,
                    fetchedAt: Date()
                )
            }
        } catch {
            // Network failure — fall back to known models
            cache[profile.id] = CacheEntry(
                models: profile.platform.knownModels,
                fetchedAt: Date()
            )
        }
    }

    /// Removes the cached model list for a profile, forcing a re-fetch
    /// on the next call to `fetchModels(for:)`.
    func invalidate(for profile: ProviderProfile) {
        cache.removeValue(forKey: profile.id)
    }

    /// Removes all cached model lists.
    func invalidateAll() {
        cache.removeAll()
    }
}

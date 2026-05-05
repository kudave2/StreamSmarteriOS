import Foundation
import SwiftData
import Observation

@Observable
final class StreamSmarterRepository {
    private let modelContext: ModelContext
    private let tmdbService: TmdbService
    private let watchmodeService: WatchmodeService

    init(
        modelContext: ModelContext,
        tmdbService: TmdbService = TmdbService(),
        watchmodeService: WatchmodeService = WatchmodeService()
    ) {
        self.modelContext = modelContext
        self.tmdbService = tmdbService
        self.watchmodeService = watchmodeService
    }

    // MARK: - User

    func getUser() throws -> User? {
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == 1 })
        return try modelContext.fetch(descriptor).first
    }

    func saveUser(_ user: User) throws {
        if let existing = try getUser() {
            modelContext.delete(existing)
        }
        modelContext.insert(user)
        try modelContext.save()
    }

    func updateUser(_ block: (User) -> Void) throws {
        guard let user = try getUser() else { return }
        block(user)
        try modelContext.save()
    }

    // MARK: - Watchlist

    func fetchWatchlistItems() throws -> [WatchlistItem] {
        let descriptor = FetchDescriptor<WatchlistItem>(sortBy: [SortDescriptor(\.priority)])
        return try modelContext.fetch(descriptor)
    }

    func insertWatchlistItem(_ item: WatchlistItem) throws {
        // Enforce Android's unique constraint: (parentTmdbId, type, seasonNumber, episodeNumber)
        let p = item.parentTmdbId
        let t = item.type
        let s = item.seasonNumber
        let e = item.episodeNumber
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate {
            $0.parentTmdbId == p && $0.type == t && $0.seasonNumber == s && $0.episodeNumber == e
        })
        let duplicates = try modelContext.fetch(descriptor)
        guard duplicates.isEmpty else { return }
        modelContext.insert(item)
        try modelContext.save()
    }

    func updateWatchlistItem(_ item: WatchlistItem) throws {
        try modelContext.save()
    }

    func deleteWatchlistItem(_ item: WatchlistItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func deleteWatchlistByParentId(_ parentTmdbId: Int) throws {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.parentTmdbId == parentTmdbId })
        try modelContext.fetch(descriptor).forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    func deleteWatchlistSeason(parentTmdbId: Int, seasonNumber: Int) throws {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate {
            $0.parentTmdbId == parentTmdbId && $0.seasonNumber == seasonNumber
        })
        try modelContext.fetch(descriptor).forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    func updateWatchStatus(item: WatchlistItem, status: String) throws {
        item.status = status
        try modelContext.save()
    }

    // MARK: - Streaming Services

    func fetchStreamingServices() throws -> [StreamingService] {
        return try modelContext.fetch(FetchDescriptor<StreamingService>())
    }

    func fetchStreamingService(byName name: String) throws -> [StreamingService] {
        let descriptor = FetchDescriptor<StreamingService>(predicate: #Predicate { $0.name == name })
        return try modelContext.fetch(descriptor)
    }

    func insertStreamingService(_ service: StreamingService) throws {
        modelContext.insert(service)
        try modelContext.save()
    }

    func updateStreamingService(_ service: StreamingService) throws {
        try modelContext.save()
    }

    func deleteStreamingService(_ service: StreamingService) throws {
        modelContext.delete(service)
        try modelContext.save()
    }

    // MARK: - Notifications

    func fetchNotifications() throws -> [AppNotification] {
        let descriptor = FetchDescriptor<AppNotification>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func insertNotification(_ notification: AppNotification) throws {
        modelContext.insert(notification)
        try modelContext.save()
    }

    func deleteNotification(_ notification: AppNotification) throws {
        modelContext.delete(notification)
        try modelContext.save()
    }

    func deleteOldNotifications() throws {
        let threshold = Date().addingTimeInterval(-60 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<AppNotification>(predicate: #Predicate { $0.timestamp < threshold })
        try modelContext.fetch(descriptor).forEach { modelContext.delete($0) }
        try modelContext.save()
    }

    func markNotificationAsRead(_ notification: AppNotification) throws {
        notification.isRead = true
        try modelContext.save()
    }

    // MARK: - TMDB Networking

    func validateTmdbApiKey(_ apiKey: String) async -> Bool {
        do {
            _ = try await tmdbService.getMovieDetails(movieId: 550, apiKey: apiKey)
            return true
        } catch {
            return false
        }
    }

    func searchTmdb(query: String, apiKey: String) async -> [TmdbSearchResult] {
        do {
            let response = try await tmdbService.searchMulti(query: query, apiKey: apiKey)
            var results: [TmdbSearchResult] = []

            for result in response.results {
                if result.mediaType == "movie" || result.mediaType == "tv" {
                    results.append(result)
                } else if result.mediaType == "person" {
                    let credits = try? await tmdbService.getPersonCredits(personId: result.id, apiKey: apiKey)
                    credits?.cast.forEach { credit in
                        if !results.contains(where: { $0.id == credit.id }) {
                            results.append(credit)
                        }
                    }
                }
            }

            return results.sorted { $0.displayDate > $1.displayDate }
        } catch {
            return []
        }
    }

    func getMovieDetails(id: Int, apiKey: String) async -> TmdbMovieDetails? {
        try? await tmdbService.getMovieDetails(movieId: id, apiKey: apiKey)
    }

    func getTvDetails(id: Int, apiKey: String) async -> TmdbTvDetails? {
        try? await tmdbService.getTvDetails(tvId: id, apiKey: apiKey)
    }

    func getTvSeasonDetails(tvId: Int, seasonNumber: Int, apiKey: String) async -> TmdbSeason? {
        try? await tmdbService.getTvSeasonDetails(tvId: tvId, seasonNumber: seasonNumber, apiKey: apiKey)
    }

    func getWatchProviders(type: String, id: Int, apiKey: String) async -> [String] {
        do {
            let response = try await tmdbService.getWatchProviders(type: type, id: id, apiKey: apiKey)
            let providers = response.results?["US"]?.flatrate?.map(\.providerName) ?? []
            return Array(Set(providers))
        } catch {
            return []
        }
    }

    // MARK: - Watchmode Networking

    func searchWatchmode(apiKey: String, searchValue: String) async -> [WatchmodeSearchResult] {
        do {
            return try await watchmodeService.searchTitle(apiKey: apiKey, searchValue: searchValue).titleResults
        } catch {
            return []
        }
    }

    func getWatchmodeSources(apiKey: String, titleId: Int) async -> [WatchmodeStreamingSource] {
        do {
            return try await watchmodeService.getSources(apiKey: apiKey, titleId: titleId)
        } catch {
            return []
        }
    }
}

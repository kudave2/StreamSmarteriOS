import Foundation
import SwiftData

@Model
final class WatchlistItem {
    var title: String
    var type: String        // "movie", "tv", "season", "episode"
    var priority: Int
    var status: String      // "Ready", "Watched"
    var streamingServiceId: Int64?
    var imageUrl: String?
    var tmdbId: Int?
    var parentTmdbId: Int = 0
    var providers: String?
    var releaseYear: String?
    var runtime: Int?
    var seasonNumber: Int = 0
    var episodeNumber: Int = 0
    var currentSeason: Int = 1
    var currentEpisode: Int = 0
    var totalSeasons: Int?
    var totalEpisodesInCurrentSeason: Int?
    var nextEpisodeName: String?
    var nextEpisodeAirDate: String?
    var overview: String?
    var watchedDate: Date?
    var watchedOn: String?

    init(
        title: String,
        type: String,
        priority: Int,
        status: String = "Ready",
        streamingServiceId: Int64? = nil,
        imageUrl: String? = nil,
        tmdbId: Int? = nil,
        parentTmdbId: Int = 0,
        providers: String? = nil,
        releaseYear: String? = nil,
        runtime: Int? = nil,
        seasonNumber: Int = 0,
        episodeNumber: Int = 0,
        currentSeason: Int = 1,
        currentEpisode: Int = 0,
        totalSeasons: Int? = nil,
        totalEpisodesInCurrentSeason: Int? = nil,
        nextEpisodeName: String? = nil,
        nextEpisodeAirDate: String? = nil,
        overview: String? = nil,
        watchedDate: Date? = nil,
        watchedOn: String? = nil
    ) {
        self.title = title
        self.type = type
        self.priority = priority
        self.status = status
        self.streamingServiceId = streamingServiceId
        self.imageUrl = imageUrl
        self.tmdbId = tmdbId
        self.parentTmdbId = parentTmdbId
        self.providers = providers
        self.releaseYear = releaseYear
        self.runtime = runtime
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.currentSeason = currentSeason
        self.currentEpisode = currentEpisode
        self.totalSeasons = totalSeasons
        self.totalEpisodesInCurrentSeason = totalEpisodesInCurrentSeason
        self.nextEpisodeName = nextEpisodeName
        self.nextEpisodeAirDate = nextEpisodeAirDate
        self.overview = overview
        self.watchedDate = watchedDate
        self.watchedOn = watchedOn
    }

    // Mirrors Android's unique constraint: (parentTmdbId, type, seasonNumber, episodeNumber)
    func isDuplicate(of other: WatchlistItem) -> Bool {
        parentTmdbId == other.parentTmdbId &&
        type == other.type &&
        seasonNumber == other.seasonNumber &&
        episodeNumber == other.episodeNumber
    }
}

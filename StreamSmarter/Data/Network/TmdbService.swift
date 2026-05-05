import Foundation

// MARK: - Response Models

struct TmdbSearchResponse: Codable {
    let results: [TmdbSearchResult]
}

struct TmdbSearchResult: Codable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let knownFor: [TmdbSearchResult]?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case knownFor = "known_for"
    }

    var displayTitle: String { title ?? name ?? "" }
    var displayDate: String { releaseDate ?? firstAirDate ?? "" }
}

struct TmdbMovieDetails: Codable {
    let id: Int
    let runtime: Int?
    let releaseDate: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case runtime
        case releaseDate = "release_date"
        case overview
    }
}

struct TmdbTvDetails: Codable {
    let id: Int
    let episodeRunTime: [Int]?
    let numberOfEpisodes: Int?
    let numberOfSeasons: Int?
    let seasons: [TmdbSeason]?
    let nextEpisodeToAir: TmdbEpisode?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case episodeRunTime = "episode_run_time"
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case seasons
        case nextEpisodeToAir = "next_episode_to_air"
        case overview
    }
}

struct TmdbSeason: Codable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int?
    let name: String?
    let airDate: String?
    let episodes: [TmdbEpisode]?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case name
        case airDate = "air_date"
        case episodes
        case overview
    }
}

struct TmdbEpisode: Codable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String?
    let airDate: String?
    let runtime: Int?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case name
        case airDate = "air_date"
        case runtime
        case overview
    }
}

struct TmdbPeopleResponse: Codable {
    let results: [TmdbPerson]
}

struct TmdbPerson: Codable {
    let id: Int
    let name: String
    let knownFor: [TmdbSearchResult]

    enum CodingKeys: String, CodingKey {
        case id, name
        case knownFor = "known_for"
    }
}

struct TmdbCreditsResponse: Codable {
    let cast: [TmdbSearchResult]
}

struct TmdbWatchProvidersResponse: Codable {
    let results: [String: TmdbWatchProvidersRegion]?
}

struct TmdbWatchProvidersRegion: Codable {
    let flatrate: [TmdbProvider]?
    let rent: [TmdbProvider]?
    let buy: [TmdbProvider]?
}

struct TmdbProvider: Codable {
    let providerName: String

    enum CodingKeys: String, CodingKey {
        case providerName = "provider_name"
    }
}

// MARK: - Service

final class TmdbService {
    private let baseURL = URL(string: "https://api.themoviedb.org/3/")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func request<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems
        let (data, _) = try await session.data(from: components.url!)
        return try decoder.decode(T.self, from: data)
    }

    func searchMulti(query: String, apiKey: String) async throws -> TmdbSearchResponse {
        try await request("search/multi", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func searchPerson(query: String, apiKey: String) async throws -> TmdbPeopleResponse {
        try await request("search/person", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func getPersonCredits(personId: Int, apiKey: String) async throws -> TmdbCreditsResponse {
        try await request("person/\(personId)/combined_credits", queryItems: [
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func getMovieDetails(movieId: Int, apiKey: String) async throws -> TmdbMovieDetails {
        try await request("movie/\(movieId)", queryItems: [
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func getTvDetails(tvId: Int, apiKey: String) async throws -> TmdbTvDetails {
        try await request("tv/\(tvId)", queryItems: [
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func getTvSeasonDetails(tvId: Int, seasonNumber: Int, apiKey: String) async throws -> TmdbSeason {
        try await request("tv/\(tvId)/season/\(seasonNumber)", queryItems: [
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }

    func getWatchProviders(type: String, id: Int, apiKey: String) async throws -> TmdbWatchProvidersResponse {
        try await request("\(type)/\(id)/watch/providers", queryItems: [
            URLQueryItem(name: "api_key", value: apiKey)
        ])
    }
}

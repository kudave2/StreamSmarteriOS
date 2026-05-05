import Foundation

// MARK: - Response Models

struct WatchmodeSearchResponse: Codable {
    let titleResults: [WatchmodeSearchResult]

    enum CodingKeys: String, CodingKey {
        case titleResults = "title_results"
    }
}

struct WatchmodeSearchResult: Codable {
    let id: Int
    let name: String
    let type: String
    let year: Int?
}

struct WatchmodeStreamingSource: Codable {
    let sourceId: Int
    let name: String
    let type: String
    let region: String

    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case name, type, region
    }
}

// MARK: - Service

final class WatchmodeService {
    private let baseURL = URL(string: "https://api.watchmode.com/v1/")!
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

    func searchTitle(apiKey: String, searchValue: String, searchType: String = "1") async throws -> WatchmodeSearchResponse {
        try await request("search/", queryItems: [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "search_value", value: searchValue),
            URLQueryItem(name: "search_type", value: searchType)
        ])
    }

    func getSources(apiKey: String, titleId: Int) async throws -> [WatchmodeStreamingSource] {
        try await request("title/\(titleId)/sources/", queryItems: [
            URLQueryItem(name: "apiKey", value: apiKey)
        ])
    }
}

import Foundation
import SwiftData
import Observation
import SwiftUI
import UserNotifications
import BackgroundTasks

enum WatchlistTab: Equatable {
    case available, unavailable, watched, search
}

struct WatchlistSelection {
    let tmdbResult: TmdbSearchResult
    let itemType: String
    let seasonNumber: Int?
    let episodeNumber: Int?
}

@Observable
@MainActor
final class WatchlistViewModel {
    private var repository: StreamSmarterRepository?
    
    var allItems: [WatchlistItem] = [] {
        didSet {
            // When allItems changes, re-evaluate the filtered and sorted list
            // This ensures that even if search query is stable, new data triggers updates
            updateFilteredAndSortedItems()
        }
    }
    
    // The search query bound to the TextField
    var searchQuery: String = "" {
        didSet {
            if searchQuery.isEmpty {
                searchDebounceTask?.cancel()
                debouncedSearchQuery = ""
                updateFilteredAndSortedItems()
            } else {
                searchDebounceTask?.cancel()
                scheduleSearchDebounce()
            }
        }
    }
    
    var analysisResults: AnalysisResults? // To get budget alert
    var services: [StreamingService] = []
    var user: User?
    
    var selectedTab: WatchlistTab = .available {
        didSet {
            updateCurrentTabItems()
        }
    }
    // Internal state for debounced search, used by filteredAndSortedItems
    private var debouncedSearchQuery: String = ""
    private var searchDebounceTask: Task<Void, Never>?
    var highlightedItemId: PersistentIdentifier?
    var pendingScrollItemId: PersistentIdentifier?
    // For Add Flow
    var previousTab: WatchlistTab = .available // To return after search
    
    var showAddSheet: Bool = false
    var searchResults: [TmdbSearchResult] = []
    var trendingResults: [TmdbSearchResult] = []
    var popularResults: [TmdbSearchResult] = []
    var recommendations: [TmdbSearchResult] = []
    var showApiKeyError: Bool = false
    var selectedResult: TmdbSearchResult? // Added to manage the detail sheet state
    var isSearching: Bool = false
    
    private let backgroundTaskID = "com.streamsmarter.refreshAirDates"
    
    func setup(repository: StreamSmarterRepository) {
        self.repository = repository
        refreshData()
        if let apiKey = user?.tmdbApiKey, !apiKey.isEmpty {
            Task {
                await repository.backfillAirDates(apiKey: apiKey)
                await fetchTrendingContent()
                refreshData()
            }
        }
    }
    
    private func scheduleSearchDebounce() {
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.debouncedSearchQuery = self.searchQuery
                    self.updateFilteredAndSortedItems() // Trigger update after debounce
                }
            } catch { /* Task was cancelled */ }
        }
    }
    
    
    func refreshData() {
        guard let repository else { return }
        do {
            self.allItems = try repository.fetchWatchlistItems()
            self.services = try repository.fetchStreamingServices()
            self.user = try repository.getUser()
            updateFilteredAndSortedItems() // Initial update
        } catch {}
    }
    
    // MARK: - Partitioning & Sorting
    
    var activeTotalCost: Double {
        let streamingCost = services.filter { $0.isActive }.reduce(0) { $1.monthlyCost + $0 }
        let mainCost = user?.mainViewingServiceCost ?? 0.0
        return streamingCost + mainCost
    }
    
    var budgetAlert: StreamingService? {
        let now = Date()
        let sevenDaysFromNow = now.addingTimeInterval(7 * 24 * 60 * 60)
        
        return services.first { service in
            guard service.isActive && service.renewalDate > now && service.renewalDate <= sevenDaysFromNow else { return false }
            let hasReadyItems = allItems.contains { isServiceMatch(normalizedServiceName: normalizeServiceName(service.name), providers: $0.providers ?? "") && $0.status == "Ready" }
            return !hasReadyItems
        }
    }
    
    // Helper to normalize service names (moved from HierarchicalWatchlistRow)
    func normalizeServiceName(_ name: String) -> String {
        let pattern = "[\\+\\s\\.\\-' ]|plus|video"
        return name.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    
    var activeServiceNames: [String] {
        let now = Date()
        var names = services.filter { 
            $0.isActive || now < $0.renewalDate
        }.map { normalizeServiceName($0.name) } // Normalize here
        
        if let main = user?.mainViewingService { names.append(normalizeServiceName(main)) } // Normalize here
        return Array(Set(names))
    }
    
    // Optimized isServiceMatch to accept already normalized service names
    func isServiceMatch(normalizedServiceName: String, providers: String) -> Bool {
        let pattern = "[\\+\\s\\.\\-' ]|plus|video"
        let pRaw = providers.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        let sRaw = normalizedServiceName // Already normalized
        return sRaw.count > 2 && pRaw.contains(sRaw) || pRaw.count > 2 && sRaw.contains(pRaw) || (sRaw == "appletv" && pRaw.contains("appletv")) || (sRaw.contains("disney") && (pRaw.contains("hulu") || pRaw.contains("espn")))
    }
    
    var filteredAndSortedItems: [WatchlistItem] {
        let topLevel = allItems.filter { $0.type == "movie" || $0.type == "tv" }
        
        let filtered = searchQuery.isEmpty ? topLevel : topLevel.filter { 
            $0.title.localizedCaseInsensitiveContains(searchQuery) 
        }

        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60 * 1000 / 1000) // 10 days

        // Map items to metadata for sorting (matches Android derivedStateOf logic)
        let itemsWithMetadata = filtered.map { item -> (item: WatchlistItem, lastActivity: Date, isAlmostDone: Bool) in
            let episodes = allItems.filter { $0.parentTmdbId == item.tmdbId && $0.type == "episode" }
            let lastActivity = episodes.filter { $0.status == "Watched" }.compactMap { $0.watchedDate }.max() ?? .distantPast
            let readyCount = episodes.filter { $0.status == "Ready" }.count
            let isAlmostDone = item.type == "tv" && (1...2).contains(readyCount)
            
            return (item, lastActivity, isAlmostDone)
        }

        let sorted = itemsWithMetadata.sorted { a, b in
            if a.isAlmostDone != b.isAlmostDone { return a.isAlmostDone && !b.isAlmostDone }
            if a.isAlmostDone { return a.item.title < b.item.title }
            
            let aIsRecent = a.lastActivity > tenDaysAgo
            let bIsRecent = b.lastActivity > tenDaysAgo
            
            if aIsRecent != bIsRecent { return aIsRecent }
            if aIsRecent { return a.lastActivity > b.lastActivity }
            
            if a.item.priority != b.item.priority { return a.item.priority < b.item.priority }
            return a.item.title < b.item.title
        }
        
        return sorted.map { $0.item }
    }
    
    // Store the computed filtered and sorted items to avoid re-computation
    private var _filteredAndSortedItems: [WatchlistItem] = []
    var availableReady: [WatchlistItem] = []
    var unavailableReady: [WatchlistItem] = []
    var watchedItems: [WatchlistItem] = []
    var currentTabItems: [WatchlistItem] = []
    
    private func updateFilteredAndSortedItems() {
        let topLevel = allItems.filter { $0.type == "movie" || $0.type == "tv" }

        if debouncedSearchQuery.isEmpty {
            // Standard business logic sorting (Almost Done -> Recent -> Priority -> Alphabetical)
            let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
            let itemsWithMetadata = topLevel.map { item -> (item: WatchlistItem, lastActivity: Date, isAlmostDone: Bool) in
                let episodes = allItems.filter { $0.parentTmdbId == item.tmdbId && $0.type == "episode" }
                let lastActivity = episodes.filter { $0.status == "Watched" }.compactMap { $0.watchedDate }.max() ?? .distantPast
                let readyCount = episodes.filter { $0.status == "Ready" }.count
                let isAlmostDone = item.type == "tv" && (1...2).contains(readyCount)
                return (item, lastActivity, isAlmostDone)
            }
            
            _filteredAndSortedItems = itemsWithMetadata.sorted { a, b in
                if a.isAlmostDone != b.isAlmostDone { return a.isAlmostDone && !b.isAlmostDone }
                if a.isAlmostDone { return a.item.title < b.item.title }
                let aIsRecent = a.lastActivity > tenDaysAgo
                let bIsRecent = b.lastActivity > tenDaysAgo
                if aIsRecent != bIsRecent { return aIsRecent }
                if aIsRecent { return a.lastActivity > b.lastActivity }
                if a.item.priority != b.item.priority { return a.item.priority < b.item.priority }
                return a.item.title < b.item.title
            }.map { $0.item }
        } else {
            // Match Android search scoring for local watchlist filtering
            let query = debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedQuery = query.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            let keywords = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            let scored: [(item: WatchlistItem, score: Int)] = topLevel.compactMap { item in
                let rawTitle = item.title.lowercased()
                let cleanTitle = rawTitle.replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let normalizedTitle = cleanTitle.replacingOccurrences(of: " ", with: "")

                let score: Int
                if rawTitle == query { score = 0 }
                else if rawTitle.hasPrefix(query) || cleanTitle.hasPrefix(query) { score = 1 }
                else if cleanTitle.contains(query) || normalizedTitle.contains(normalizedQuery) { score = 2 }
                else if keywords.allSatisfy({ rawTitle.contains($0) }) { score = 3 }
                else if keywords.contains(where: { rawTitle.contains($0) }) { score = 4 }
                else { score = 5 }

                return score < 5 ? (item, score) : nil
            }

            _filteredAndSortedItems = scored.sorted { (a: (item: WatchlistItem, score: Int), b: (item: WatchlistItem, score: Int)) -> Bool in
                // 1. Tier First
                if a.score != b.score { return a.score < b.score }
                
                let aTitle = a.item.title.lowercased()
                let bTitle = b.item.title.lowercased()
                
                // 2. Phrase match priority
                let aContains = aTitle.contains(query)
                let bContains = bTitle.contains(query)
                if aContains != bContains { return aContains && !bContains }
                
                // 3. Shorter titles win
                if aTitle.count != bTitle.count { return aTitle.count < bTitle.count }
                
                // 4. Alphabetical
                return aTitle < bTitle
            }.map { $0.item }
        }
        
        // Update tabs based on the new results
        availableReady = _filteredAndSortedItems.filter { $0.status == "Ready" && isAvailableOnActive($0) }
        unavailableReady = _filteredAndSortedItems.filter { $0.status == "Ready" && !isAvailableOnActive($0) }
        watchedItems = _filteredAndSortedItems.filter { $0.status == "Watched" }
        
        updateCurrentTabItems()
    }

    private func updateCurrentTabItems() {
        // Update currentTabItems based on the selected tab
        switch selectedTab {
        case .available: currentTabItems = availableReady
        case .unavailable: currentTabItems = unavailableReady
        case .watched: currentTabItems = watchedItems
        case .search: currentTabItems = _filteredAndSortedItems
        }
    }
    
    private func isAvailableOnActive(_ item: WatchlistItem) -> Bool {
        guard let providers = item.providers else { return false }
        return activeServiceNames.contains { normalizedService in
            isServiceMatch(normalizedServiceName: normalizedService, providers: providers)
        }
    }
    
    // MARK: - Hierarchy Logic
    
    func updateHierarchyStatus(_ item: WatchlistItem, newStatus: String) {
        guard let repository else { return }
        let now = Date()
        
        // Determine which service it was watched on
        let watchedOn = newStatus == "Watched" ? determineWatchedOn(item) : nil

        // 1. Update the item itself
        item.status = newStatus
        item.watchedDate = (newStatus == "Watched") ? (item.watchedDate ?? now) : nil
        item.watchedOn = watchedOn
        
        // 2. Propagate DOWN (Show -> Seasons -> Episodes)
        if item.type == "tv" || item.type == "season" {
            let children = allItems.filter { 
                $0.parentTmdbId == item.parentTmdbId && 
                (item.type == "tv" ? true : $0.seasonNumber == item.seasonNumber) &&
                $0.id != item.id
            }
            for child in children {
                child.status = newStatus
                child.watchedDate = (newStatus == "Watched") ? (child.watchedDate ?? now) : nil
                child.watchedOn = (newStatus == "Watched") ? determineWatchedOn(child) : nil
            }
        }
        
        // 3. Propagate UP (Episode -> Season -> Show)
        propagateStatusUp(for: item)
        
        try? repository.updateWatchlistItem(item)
        refreshData()
    }

    private func propagateStatusUp(for item: WatchlistItem) {
        if item.type == "episode" {
            guard let season = allItems.first(where: { 
                $0.type == "season" && $0.parentTmdbId == item.parentTmdbId && $0.seasonNumber == item.seasonNumber 
            }) else { return }
            
            let siblings = allItems.filter { 
                $0.type == "episode" && $0.parentTmdbId == item.parentTmdbId && $0.seasonNumber == item.seasonNumber 
            }
            
            let nextStatus = siblings.allSatisfy { $0.status == "Watched" } ? "Watched" : "Ready"
            if season.status != nextStatus {
                season.status = nextStatus
                season.watchedDate = (nextStatus == "Watched") ? Date() : nil
                season.watchedOn = (nextStatus == "Watched") ? determineWatchedOn(season) : nil
                propagateStatusUp(for: season)
            }
        } else if item.type == "season" {
            guard let show = allItems.first(where: { 
                $0.type == "tv" && $0.tmdbId == item.parentTmdbId 
            }) else { return }
            
            let siblings = allItems.filter { 
                $0.type == "season" && $0.parentTmdbId == item.parentTmdbId 
            }
            
            let nextStatus = siblings.allSatisfy { $0.status == "Watched" } ? "Watched" : "Ready"
            if show.status != nextStatus {
                show.status = nextStatus
                show.watchedDate = (nextStatus == "Watched") ? Date() : nil
                show.watchedOn = (nextStatus == "Watched") ? determineWatchedOn(show) : nil
            }
        }
    }

    private func determineWatchedOn(_ item: WatchlistItem) -> String? {
        let mainService = user?.mainViewingService
        guard let providers = item.providers, providers != "None Found" else { return mainService }
        
        if let main = mainService, isServiceMatch(normalizedServiceName: normalizeServiceName(main), providers: providers) {
            return main
        }
        
        let activeServices = services.filter { $0.isActive }.sorted { $0.monthlyCost < $1.monthlyCost }
        for service in activeServices {
            if isServiceMatch(normalizedServiceName: normalizeServiceName(service.name), providers: providers) {
                return service.name
            }
        }
        return mainService
    }
    
    private func nextReadyEpisodeText(for show: WatchlistItem) -> String? {
        guard let showId = show.tmdbId else { return nil }
        let readyEpisodes = allItems.filter {
            $0.type == "episode" &&
            $0.parentTmdbId == showId &&
            $0.status == "Ready"
        }
        let nextEpisode = readyEpisodes.sorted {
            if $0.seasonNumber != $1.seasonNumber {
                return $0.seasonNumber < $1.seasonNumber
            }
            return $0.episodeNumber < $1.episodeNumber
        }.first
        guard let episode = nextEpisode else { return nil }
        let episodeTitlePart = episode.title.isEmpty ? "" : ": \(episode.title)"
        return "S\(episode.seasonNumber)E\(episode.episodeNumber)\(episodeTitlePart)"
    }
    
    func deleteHierarchy(_ item: WatchlistItem) {
        guard let repository else { return }
        do {
            if item.type == "tv" {
                // Delete all seasons and episodes first
                if let id = item.tmdbId {
                    try repository.deleteWatchlistByParentId(id)
                }
                // Delete the show itself
                try repository.deleteWatchlistItem(item)
            } else if item.type == "season" {
                // Delete all episodes in this season
                try repository.deleteWatchlistSeason(parentTmdbId: item.parentTmdbId, seasonNumber: item.seasonNumber)
                // Delete the season itself
                try repository.deleteWatchlistItem(item)
            } else {
                // Delete just the episode or movie
                try repository.deleteWatchlistItem(item)
            }
            refreshData()
        } catch {}
    }
    
    func handleSearchSelection(item: WatchlistItem) {
        // Dismiss keyboard first to avoid layout jumps during transition
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let targetTab: WatchlistTab
        if item.status == "Watched" {
            targetTab = .watched
        } else if activeServiceNames.contains(where: { isServiceMatch(normalizedServiceName: $0, providers: item.providers ?? "") }) {
            targetTab = .available
        } else {
            targetTab = .unavailable
        }

        // Clear highlight from previous selections
        highlightedItemId = item.persistentModelID
        
        // Switch tab and clear query simultaneously to trigger the View swap
        self.selectedTab = targetTab
        self.searchQuery = "" 

        // Delay the scroll request to allow the View to switch and render the new List rows
        Task {
            try? await Task.sleep(nanoseconds: 850_000_000) // 0.85s for safer rendering
            self.pendingScrollItemId = item.persistentModelID
            
            // Clear highlight after 2.5 seconds
            try await Task.sleep(nanoseconds: 2_500_000_000)
            if highlightedItemId == item.persistentModelID {
                highlightedItemId = nil
            }
        }
    }
    
    // MARK: - Search & Add
    
    func fetchTrendingContent() async {
        guard let repository else { return }
        refreshData()

        guard let apiKey = user?.tmdbApiKey, !apiKey.isEmpty else { return }
        
        isSearching = true
        
        // IMPORTANT: Ensure your repository has a method that fetches from a PATH 
        // rather than passing these paths as a 'query' string to the search endpoint.
        async let trending = repository.fetchTmdbEndpoint("trending/all/day", apiKey: apiKey)
        async let popularMovies = repository.fetchTmdbEndpoint("movie/popular", apiKey: apiKey)
        async let popularTV = repository.fetchTmdbEndpoint("tv/popular", apiKey: apiKey)
        
        let (tResults, mResults, tvResults) = await (trending, popularMovies, popularTV)
        
        // Use a shared set to prevent duplicates across both sections
        var seenDiscoveryIds = Set<Int>()
        
        self.trendingResults = processDiscoveryResults(tResults, limit: 10, seenIds: &seenDiscoveryIds)
        
        // Combine Movie and TV results to ensure we have a large enough pool to get 5 valid items
        var popularPool = mResults
        popularPool.append(contentsOf: tvResults)
        popularPool.shuffle() 
        self.popularResults = processDiscoveryResults(popularPool, limit: 10, seenIds: &seenDiscoveryIds)
        
        isSearching = false
    }

    private func processDiscoveryResults(_ results: [TmdbSearchResult], limit: Int, seenIds: inout Set<Int>) -> [TmdbSearchResult] {
        var processed: [TmdbSearchResult] = []
        
        for item in results {
            let title = item.title ?? item.name ?? ""
            
            // Relax restriction: as long as there is a title, we allow it.
            // The UI (TmdbResultCard) already handles missing posters with a placeholder.
            if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                // Ensure we don't have duplicates within the same section
                if !seenIds.contains(item.id) {
                    seenIds.insert(item.id)
                    processed.append(item)
                }
            }
            if processed.count >= limit { break }
        }
        return processed
    }

    private func sortTmdbResults(_ results: [TmdbSearchResult], query: String) -> [TmdbSearchResult] {
        if query.isEmpty { return results }
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedQuery = cleanQuery.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        let keywords = cleanQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        let scored: [(item: TmdbSearchResult, score: Int)] = results.compactMap { item in
            let rawTitle = (item.title ?? item.name ?? "").lowercased()
            let cleanTitle = rawTitle.replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let normalizedTitle = cleanTitle.replacingOccurrences(of: " ", with: "")

            let score: Int
            if rawTitle == cleanQuery { score = 0 }
            else if rawTitle.hasPrefix(cleanQuery) || cleanTitle.hasPrefix(cleanQuery) { score = 1 }
            else if cleanTitle.contains(cleanQuery) || normalizedTitle.contains(normalizedQuery) { score = 2 }
            else if keywords.allSatisfy({ rawTitle.contains($0) }) { score = 3 }
            else if keywords.contains(where: { rawTitle.contains($0) }) { score = 4 }
            else { score = 5 }

            return score < 5 ? (item, score) : nil
        }

        let sorted = scored.sorted { (a: (item: TmdbSearchResult, score: Int), b: (item: TmdbSearchResult, score: Int)) -> Bool in
            // 1. Tier First
            if a.score != b.score { return a.score < b.score }
            
            let aTitle = (a.item.title ?? a.item.name ?? "").lowercased()
            let bTitle = (b.item.title ?? b.item.name ?? "").lowercased()
            
            // 2. Phrase match priority
            let aContains = aTitle.contains(cleanQuery)
            let bContains = bTitle.contains(cleanQuery)
            if aContains != bContains { return aContains && !bContains }
            
            // 3. Shorter titles win
            return aTitle.count < bTitle.count
        }
        
        return sorted.map { $0.item }
    }

    func searchTmdb(_ query: String) async {
        guard let repository, let apiKey = user?.tmdbApiKey else { return }
        
        if query.isEmpty {
            searchResults = []
            return
        }

        isSearching = true
        let results = await repository.searchTmdb(query: query, apiKey: apiKey)
        
        // Health Check: If search returns no results, verify if the API key is valid
        if results.isEmpty {
            let isValid = await repository.validateTmdbApiKey(apiKey)
            self.showApiKeyError = !isValid
        } else {
            self.showApiKeyError = false
        }
        
        searchResults = sortTmdbResults(results, query: query)
        isSearching = false
    }
    
    func isItemInWatchlist(tmdbId: Int) -> Bool {
        allItems.contains { $0.tmdbId == tmdbId || $0.parentTmdbId == tmdbId }
    }
    
    func fetchRecommendations(for tmdbId: Int, type: String) async {
        guard let repository, let apiKey = user?.tmdbApiKey else { return }
        // Fetch similar content based on what was just added
        let results = await repository.searchTmdb(query: "\(type)/\(tmdbId)/recommendations", apiKey: apiKey)
        self.recommendations = results
    }
    
    func addItemsToWatchlist(selections: [WatchlistSelection], priority: Int) async {
        guard repository != nil else { return }
        
        for selection in selections {
            await addWatchlistItemInternal(
                result: selection.tmdbResult,
                type: selection.itemType,
                priority: priority,
                seasonNumber: selection.seasonNumber,
                episodeNumber: selection.episodeNumber
            )
        }

        searchQuery = ""
        searchResults = []

        // Discovery loop: Suggest items based on the last addition after the batch completes
        if let lastItem = selections.last {
            await fetchRecommendations(for: lastItem.tmdbResult.id, type: lastItem.itemType)
        }
        refreshData()
    }
    
    private func addWatchlistItemInternal(
        result: TmdbSearchResult,
        type: String,
        priority: Int,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) async {
        guard let repository, let apiKey = user?.tmdbApiKey else { return }
        
        let providersString = await fetchProviders(for: result)
        let releaseDate = result.releaseDate ?? result.firstAirDate
        let year = releaseDate?.prefix(4).description
        
        // Check for existing item (update if found)
        let existingItem = allItems.first { item in
            item.type == type &&
            item.parentTmdbId == result.id && // Use result.id as parent for all
            item.seasonNumber == (seasonNumber ?? 0) &&
            item.episodeNumber == (episodeNumber ?? 0)
        }
        
        if let existingItem = existingItem {
            // Update existing item with potentially new details
            var updatedOverview: String? = nil
            var updatedRuntime: Int? = nil
            var updatedTitle = result.title ?? result.name ?? existingItem.title
            
            if type == "movie" {
                let details = await repository.getMovieDetails(id: result.id, apiKey: apiKey)
                updatedOverview = details?.overview
                updatedRuntime = details?.runtime
            } else if type == "tv" {
                let details = await repository.getTvDetails(id: result.id, apiKey: apiKey)
                updatedOverview = details?.overview
                updatedRuntime = details?.episodeRunTime?.first
            } else if type == "season", let sn = seasonNumber {
                let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
                updatedOverview = sDetails?.overview
                updatedTitle = sDetails?.name ?? updatedTitle
            } else if type == "episode", let sn = seasonNumber, let en = episodeNumber {
                let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
                let epDetails = sDetails?.episodes?.first(where: { $0.episodeNumber == en })
                updatedOverview = epDetails?.overview
                let fallbackRuntime = (await repository.getTvDetails(id: result.id, apiKey: apiKey))?.episodeRunTime?.first
                updatedRuntime = epDetails?.runtime ?? fallbackRuntime
                updatedTitle = epDetails?.name ?? updatedTitle
            }
            
            existingItem.title = updatedTitle
            existingItem.overview = updatedOverview ?? existingItem.overview
            existingItem.runtime = updatedRuntime ?? existingItem.runtime
            try? repository.updateWatchlistItem(existingItem)
            return
        }
        
        // If adding a season or episode, ensure parent TV show exists
        if type == "season" || type == "episode" {
            let parentShowExists = allItems.contains(where: { $0.type == "tv" && $0.tmdbId == result.id })
            if !parentShowExists {
                let tvDetails = await repository.getTvDetails(id: result.id, apiKey: apiKey)
                let parentShow = WatchlistItem(
                    title: result.name ?? result.title ?? "Unknown Show",
                    type: "tv",
                    priority: priority,
                    tmdbId: result.id,
                    parentTmdbId: result.id,
                    providers: providersString,
                    releaseYear: year,
                    airDate: result.airDate,
                    runtime: tvDetails?.episodeRunTime?.first,
                    totalSeasons: tvDetails?.numberOfSeasons,
                    overview: tvDetails?.overview
                )
                try? repository.insertWatchlistItem(parentShow)
            }
        }
        
        // If adding an episode, ensure parent season exists
        if type == "episode", let sn = seasonNumber {
            let seasonExists = allItems.contains(where: { 
                $0.type == "season" && $0.parentTmdbId == result.id && $0.seasonNumber == sn 
            })
            if !seasonExists {
                let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
                let parentSeason = WatchlistItem(
                    title: sDetails?.name ?? "Season \(sn)",
                    type: "season",
                    priority: priority,
                    parentTmdbId: result.id,
                    providers: providersString,
                    releaseYear: sDetails?.airDate?.prefix(4).description,
                    airDate: sDetails?.parsedAirDate,
                    seasonNumber: sn,
                    totalEpisodesInCurrentSeason: sDetails?.episodeCount,
                    overview: sDetails?.overview
                )
                try? repository.insertWatchlistItem(parentSeason)
            }
        }
        
        // Create the new item
        var itemTitle = result.title ?? result.name ?? "Unknown"
        var runtime: Int? = nil
        var totalSeasons: Int? = nil
        var epsInSeason: Int? = nil
        var overview: String? = nil
        
        if type == "movie" {
            let details = await repository.getMovieDetails(id: result.id, apiKey: apiKey)
            runtime = details?.runtime
            overview = details?.overview
        } else if type == "tv" {
            let details = await repository.getTvDetails(id: result.id, apiKey: apiKey)
            runtime = details?.episodeRunTime?.first
            totalSeasons = details?.numberOfSeasons
            overview = details?.overview
        } else if type == "season", let sn = seasonNumber {
            let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
            itemTitle = sDetails?.name ?? "Season \(sn)"
            epsInSeason = sDetails?.episodeCount
            overview = sDetails?.overview
        } else if type == "episode", let sn = seasonNumber, let en = episodeNumber {
            let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
            let epDetails = sDetails?.episodes?.first(where: { $0.episodeNumber == en })
            itemTitle = epDetails?.name ?? "Episode \(en)"
            let fallbackRuntime = (await repository.getTvDetails(id: result.id, apiKey: apiKey))?.episodeRunTime?.first
            runtime = epDetails?.runtime ?? fallbackRuntime
            overview = epDetails?.overview
        }
        
        var airDate: Date? = nil
        
        if type == "movie" || type == "tv" {
            airDate = result.airDate
        } else if type == "season", let sn = seasonNumber {
            let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
            airDate = sDetails?.parsedAirDate
        } else if type == "episode", let sn = seasonNumber, let en = episodeNumber {
            let sDetails = await repository.getTvSeasonDetails(tvId: result.id, seasonNumber: sn, apiKey: apiKey)
            let epDetails = sDetails?.episodes?.first(where: { $0.episodeNumber == en })
            airDate = epDetails?.parsedAirDate
        }
        
        let newItem = WatchlistItem(
            title: itemTitle,
            type: type,
            priority: priority,
            tmdbId: (type == "tv" || type == "movie") ? result.id : nil, // Only top-level items get their own TMDB ID
            parentTmdbId: result.id, // Parent is always the TV show's TMDB ID for seasons/episodes
            providers: providersString,
            releaseYear: (type == "tv" || type == "movie") ? year : nil,
            airDate: airDate,
            runtime: runtime,
            seasonNumber: seasonNumber ?? 0,
            episodeNumber: episodeNumber ?? 0,
            totalSeasons: totalSeasons,
            totalEpisodesInCurrentSeason: epsInSeason,
            overview: overview
        )
        try? repository.insertWatchlistItem(newItem)
    }
    
    // MARK: - Background Processing
    
    /// Schedules the next background refresh task
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        // Try to run the refresh at least once every 24 hours
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    /// The logic that runs when the OS wakes the app up
    func performBackgroundRefresh(task: BGAppRefreshTask) async {
        // Schedule the next refresh before starting this one
        scheduleBackgroundRefresh()
        
        task.expirationHandler = {
            // Clean up if the OS kills the task
        }
        
        guard let repository, let apiKey = user?.tmdbApiKey else {
            task.setTaskCompleted(success: false)
            return
        }

        // Only refresh shows that are "Ready" and explicitly flagged by the user
        let flaggedShows = allItems.filter { item in
            item.type == "tv" && item.status == "Ready" && item.isFlaggedForNotifications
        }
        
        var updatedCount = 0
        for show in flaggedShows {
            guard let showID = show.tmdbId else { continue }
            
            if let details = await repository.getTvDetails(id: showID, apiKey: apiKey) {
                if let nextEp = details.nextEpisodeToAir, let airDateStr = nextEp.airDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    
                    if let airDate = formatter.date(from: airDateStr), airDate > Date() {
                        show.nextEpisodeName = nextEp.name
                        show.nextEpisodeAirDate = airDateStr
                        show.nextEpisodeSeasonNumber = nextEp.seasonNumber
                        show.nextEpisodeNumber = nextEp.episodeNumber
                        try? repository.updateWatchlistItem(show)

                        scheduleAirDateNotifications(for: show, airDate: airDate)
                        updatedCount += 1
                    }
                }
            }
        }
        
        print("Background refresh completed. Updated \(updatedCount) shows.")
        task.setTaskCompleted(success: true)
    }
    
    func toggleNotificationFlag(for item: WatchlistItem) {
        guard let repository, item.type == "tv" else { return }
        
        item.isFlaggedForNotifications.toggle()
        
        if item.isFlaggedForNotifications {
            // If turning ON, check for current air date and schedule immediately
            Task {
                if let showID = item.tmdbId, let details = await repository.getTvDetails(id: showID, apiKey: user?.tmdbApiKey ?? "") {
                    if let nextEp = details.nextEpisodeToAir, let airDateStr = nextEp.airDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let airDate = formatter.date(from: airDateStr) {
                        item.nextEpisodeName = nextEp.name
                        item.nextEpisodeAirDate = airDateStr
                        item.nextEpisodeSeasonNumber = nextEp.seasonNumber
                        item.nextEpisodeNumber = nextEp.episodeNumber
                        try? repository.updateWatchlistItem(item)

                        scheduleAirDateNotifications(for: item, airDate: airDate)
                        }
                    }
                }
            }
        } else {
            // If turning OFF, cancel pending notifications for this show
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(item.title)-1day-alert", "\(item.title)-2day-alert", "\(item.title)-5day-alert"])
        }
        
        try? repository.updateWatchlistItem(item)
        refreshData()
    }
    
    func refreshSeasonEpisodes(_ season: WatchlistItem) async {
        guard let repository, let apiKey = user?.tmdbApiKey else { return }
        if let sDetails = await repository.getTvSeasonDetails(tvId: season.parentTmdbId, seasonNumber: season.seasonNumber, apiKey: apiKey) {
            for ep in sDetails.episodes ?? [] {
                if let existing = allItems.first(where: { 
                    $0.type == "episode" && 
                    $0.parentTmdbId == season.parentTmdbId && 
                    $0.seasonNumber == season.seasonNumber && 
                    $0.episodeNumber == ep.episodeNumber 
                }) {
                    existing.overview = ep.overview
                    existing.runtime = ep.runtime
                    try? repository.updateWatchlistItem(existing)
                }
            }
            refreshData()
        }
    }
    
    func launchStreamingApp(serviceName: String, title: String) {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let sRaw = serviceName.lowercased().replacingOccurrences(of: "[\\+\\s\\.\\-' ]|plus|video", with: "", options: .regularExpression)
        
        // Optimized for iOS Universal Links (Handoff to Apps)
        let urlMap: [String: String] = [
            "netflix": "https://www.netflix.com/search?q=\(encodedTitle)",
            "hulu": "https://www.hulu.com/search?q=\(encodedTitle)",
            "disney": "https://www.disneyplus.com/search?q=\(encodedTitle)",
            "amazon": "https://www.amazon.com/gp/video/search?phrase=\(encodedTitle)",
            "prime": "https://www.amazon.com/gp/video/search?phrase=\(encodedTitle)",
            "max": "https://www.max.com/search/\(encodedTitle)",
            "hbo": "https://www.max.com/search/\(encodedTitle)",
            "peacock": "https://www.peacocktv.com/watch/search?q=\(encodedTitle)",
            "paramount": "https://www.paramountplus.com/search/?q=\(encodedTitle)",
            "apple": "https://tv.apple.com/search?term=\(encodedTitle)",
            "youtube": "https://www.youtube.com/results?search_query=\(encodedTitle)"
        ]
        
        var targetUrlString = "https://www.google.com/search?q=watch+\(encodedTitle)+on+\(serviceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        for (key, url) in urlMap {
            if sRaw.contains(key) {
                targetUrlString = url
                break
            }
        }
        
        if let url = URL(string: targetUrlString) {
            // Universal links (https) don't strictly require canOpenURL check 
            // and will fallback to Safari if the app is missing.
            // Custom schemes (like peacock://) would require Info.plist entries.
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Notifications
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleAirDateNotifications(for item: WatchlistItem, airDate: Date) {
        let center = UNUserNotificationCenter.current()
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM-dd-yyyy (EEEE)"
        let formattedDate = displayFormatter.string(from: airDate)
        
        let scheduleAction = { (daysBefore: Int) in
            // Calculate notification date (e.g., 9:00 AM 1 or 2 days before)
            guard let notifyDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: airDate) else { return }
            
            // Ensure we aren't scheduling a notification in the past
            if notifyDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Release: \(item.title)"
                
                var body = ""
                if item.type == "tv" {
                    if let s = item.nextEpisodeSeasonNumber {
                        body += "Season: \(s)\n"
                    }
                    if let e = item.nextEpisodeNumber {
                        body += "Episode: \(e)"
                        if let name = item.nextEpisodeName, !name.isEmpty {
                            body += " - \(name)"
                        }
                        body += "\n"
                    }
                }
                body += "Releasing on: \(formattedDate)"
                
                content.body = body
                content.sound = .default
                
                // Create a trigger for 9:00 AM on that day
                var components = Calendar.current.dateComponents([.year, .month, .day], from: notifyDate)
                components.hour = 9
                components.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "\(item.title)-\(daysBefore)day-alert"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request)
            }
        }
        
        // Schedule advance alerts
        scheduleAction(5)
        scheduleAction(2)
        scheduleAction(1)
    }
    
    func getTvDetails(id: Int) async -> TmdbTvDetails? {
        guard let repository, let apiKey = user?.tmdbApiKey else { return nil }
        return await repository.getTvDetails(id: id, apiKey: apiKey)
    }
    
    func getTvSeasonDetails(tvId: Int, seasonNumber: Int) async -> TmdbSeason? {
        guard let repository, let apiKey = user?.tmdbApiKey else { return nil }
        return await repository.getTvSeasonDetails(tvId: tvId, seasonNumber: seasonNumber, apiKey: apiKey)
    }
    
    func fetchProviders(for result: TmdbSearchResult) async -> String? {
        guard let repository, let apiKey = user?.tmdbApiKey else { return nil }
        let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
        let list = await repository.getWatchProviders(type: mediaType, id: result.id, apiKey: apiKey)
        return list.isEmpty ? nil : list.joined(separator: ", ")
    }
    
}
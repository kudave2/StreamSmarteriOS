import Foundation
import SwiftData
import Observation
import SwiftUI
import UserNotifications
import BackgroundTasks

enum WatchlistTab {
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
    
    var allItems: [WatchlistItem] = []
    var services: [StreamingService] = []
    var user: User?
    
    var selectedTab: WatchlistTab = .available
    var searchQuery: String = ""
    
    // For Add Flow
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
    
    func refreshData() {
        guard let repository else { return }
        do {
            self.allItems = try repository.fetchWatchlistItems()
            self.services = try repository.fetchStreamingServices()
            self.user = try repository.getUser()
        } catch {}
    }
    
    // MARK: - Partitioning & Sorting
    
    private var activeServiceNames: [String] {
        let now = Date()
        var names = services.filter { 
            $0.isActive || 
            $0.renewalDate > now || 
            ($0.monthlyCost > 0.0 && $0.monthlyCost < 1.0) // Include Shared/Free services
        }.map { $0.name }
        
        if let main = user?.mainViewingService { names.append(main) }
        return Array(Set(names))
    }
    
    var filteredAndSortedItems: [WatchlistItem] {
        let topLevel = allItems.filter { $0.type == "movie" || $0.type == "tv" }
        
        let filtered = searchQuery.isEmpty ? topLevel : topLevel.filter { 
            $0.title.localizedCaseInsensitiveContains(searchQuery) 
        }
        
        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 60 * 60)
        
        return filtered.sorted { (a, b) -> Bool in
            // Boost logic: check for recent activity in episodes
            let aActivity = a.type == "tv" ? (allItems.filter { $0.parentTmdbId == a.tmdbId && $0.type == "episode" && $0.status == "Watched" }.compactMap { $0.watchedDate }.max() ?? .distantPast) : .distantPast
            let bActivity = b.type == "tv" ? (allItems.filter { $0.parentTmdbId == b.tmdbId && $0.type == "episode" && $0.status == "Watched" }.compactMap { $0.watchedDate }.max() ?? .distantPast) : .distantPast
            
            let aIsRecent = aActivity > tenDaysAgo
            let bIsRecent = bActivity > tenDaysAgo
            
            if aIsRecent != bIsRecent { return aIsRecent }
            if aIsRecent && bIsRecent { return aActivity > bActivity }
            
            if a.priority != b.priority { return a.priority < b.priority }
            return a.title < b.title
        }
    }
    
    var availableReady: [WatchlistItem] {
        filteredAndSortedItems.filter { $0.status == "Ready" && isAvailableOnActive($0) }
    }
    
    var unavailableReady: [WatchlistItem] {
        filteredAndSortedItems.filter { $0.status == "Ready" && !isAvailableOnActive($0) }
    }
    
    var watchedItems: [WatchlistItem] {
        filteredAndSortedItems.filter { $0.status == "Watched" }
    }
    
    var currentTabItems: [WatchlistItem] {
        switch selectedTab {
        case .available: return availableReady
        case .unavailable: return unavailableReady
        case .watched: return watchedItems
        case .search: return filteredAndSortedItems
        }
    }
    
    private func isAvailableOnActive(_ item: WatchlistItem) -> Bool {
        guard let providers = item.providers else { return false }
        return activeServiceNames.contains { isServiceMatch(serviceName: $0, providers: providers) }
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
        
        if let main = mainService, isServiceMatch(serviceName: main, providers: providers) {
            return main
        }
        
        let activeServices = services.filter { $0.isActive }.sorted { $0.monthlyCost < $1.monthlyCost }
        for service in activeServices {
            if isServiceMatch(serviceName: service.name, providers: providers) {
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
        
        searchResults = results
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
    
    // Re-implemented normalization from Kotlin
    func isServiceMatch(serviceName: String, providers: String) -> Bool {
        let pLower = providers.lowercased()
        let sLower = serviceName.lowercased()
        
        // Strip everything except alphanumeric characters
        let pRaw = pLower.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let sRaw = sLower.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        
        // Normalize by removing common "noise" words
        let noise = ["plus", "video", "tv", "premium", "withads"]
        var cleanSRaw = sRaw
        var cleanPRaw = pRaw
        for word in noise {
            cleanSRaw = cleanSRaw.replacingOccurrences(of: word, with: "")
            cleanPRaw = cleanPRaw.replacingOccurrences(of: word, with: "")
        }

        if cleanSRaw.count > 2 && cleanPRaw.contains(cleanSRaw) { return true }
        if cleanPRaw.count > 2 && cleanSRaw.contains(cleanPRaw) { return true }

        // Bundle Logic (Disney/Hulu/ESPN)
        let bundle = ["disney", "hulu", "espn"]
        if bundle.contains(where: { cleanSRaw.contains($0) }) && 
           bundle.contains(where: { cleanPRaw.contains($0) }) {
            return true
        }

        // Live TV / Network Mappings (Android-style robust matching)
        let liveTV = ["youtube", "fubo", "sling", "hulu", "direct"]
        let networks = ["fox", "abc", "cbs", "nbc", "cw", "fx", "amc", "bravo", "usa", "tbs", "tnt", "discovery"]
        
        if liveTV.contains(where: { cleanSRaw.contains($0) }) && 
           networks.contains(where: { cleanPRaw.contains($0) }) {
            return true
        }
        return false
    }
}
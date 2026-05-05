import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AnalysisViewModel {
    private var repository: StreamSmarterRepository?
    
    var results: AnalysisResults?
    var watchlist: [WatchlistItem] = []
    var services: [StreamingService] = []
    var user: User?
    
    // Market Price Reference: Acts as the "gathered" data for "brainy" optimization
    private var marketPrices: [String: (display: String, cost: Double)] = [
        "netflix": (display: "Netflix", cost: 15.49),
        "hulu": (display: "Hulu", cost: 14.99),
        "disney": (display: "Disney+", cost: 13.99),
        "max": (display: "Max", cost: 15.99),
        "paramount": (display: "Paramount+", cost: 11.99),
        "apple": (display: "Apple TV+", cost: 9.99),
        "peacock": (display: "Peacock", cost: 5.99),
        "amazon": (display: "Amazon Prime Video", cost: 8.99),
        "prime": (display: "Prime Video", cost: 8.99),
        "discovery": (display: "Discovery+", cost: 4.99),
        "youtube": (display: "YouTube", cost: 18.99),
        "crunchyroll": (display: "Crunchyroll", cost: 7.99)
    ]

    func setup(repository: StreamSmarterRepository) {
        self.repository = repository
        
        // Automatic Sync: Every time the context is set up (app navigation/opening)
        Task {
            await syncMarketCosts()
            calculateAnalysis()
        }
    }
    // test a change
    /// Fetches the latest market costs from GitHub and overwrites local $0.00 inactive services.
    private func syncMarketCosts() async {
        guard let repository = repository else { return }
        let urlString = "https://raw.githubusercontent.com/kudave2/StreamSmarterData/main/market_costs.csv"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return }
            
            // Parse CSV: Expecting "service_name,cost" per line
            let lines = csvString.components(separatedBy: .newlines)
            var remotePrices: [String: Double] = [:]
            
            for line in lines where !line.isEmpty {
                let columns = line.components(separatedBy: ",")
                if columns.count >= 2, 
                   let cost = Double(columns[1].trimmingCharacters(in: .whitespaces)) {
                    let displayCaseName = columns[0].trimmingCharacters(in: .whitespaces)
                    remotePrices[displayCaseName] = cost
                }
            }
            
            // Update internal marketPrices dictionary with lowercased keys for fuzzy matching,
            // and store the display name for later use.
            var lowercasedPrices: [String: (display: String, cost: Double)] = [:]
            if !remotePrices.isEmpty {
                for (name, price) in remotePrices {
                    lowercasedPrices[name.lowercased()] = (display: name, cost: price)
                }
                self.marketPrices = lowercasedPrices
            }
            
            let localServices = try repository.fetchStreamingServices()

            // Missing Service Check & Add: If a service is in GitHub but not locally, add it as 'Not Activated'
            for (remoteNameDisplayCase, _) in remotePrices {
                let remoteNameLowercased = remoteNameDisplayCase.lowercased()
                let exists = localServices.contains { local in
                    isServiceMatch(serviceName: remoteNameLowercased, providers: local.name)
                }
                
                if !exists {
                    let newService = StreamingService(
                        name: remoteNameDisplayCase, // Use the original casing for the display name
                        startDate: Date(),
                        renewalDate: Date(),
                        monthlyCost: 0.0, // Added with 0 monthly cost as per requirement
                        isActive: false   // Inactive status
                    )
                    try? repository.insertStreamingService(newService)
                }
            }
            
            // Update existing services with new casing from GitHub if their cost is 0.0
            for service in localServices {
                if service.monthlyCost == 0.0 { // Only update if user hasn't set a custom price
                    for (remoteNameLowercased, value) in marketPrices {
                        if isServiceMatch(serviceName: remoteNameLowercased, providers: service.name) {
                            // Update the display name to match GitHub's casing
                            service.name = value.display
                            try? repository.updateStreamingService(service)
                            break
                        }
                    }
                }
            }
        } catch {
            print("Market cost sync failed: \(error.localizedDescription)")
        }
    }
    
    func calculateAnalysis() {
        guard let repository else { return }
        do {
            self.watchlist = try repository.fetchWatchlistItems()
            self.services = try repository.fetchStreamingServices()
            self.user = try repository.getUser()
            
            if watchlist.isEmpty && services.isEmpty {
                self.results = nil
                return
            }
            
            let now = Date()
            let tenDaysFromNow = now.addingTimeInterval(10 * 24 * 60 * 60)
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            
            // 1. Determine Management Services (Active + Virtual Main Service)
            let activeServices = services.filter { service in
                let renewalThreshold = service.renewalDate.addingTimeInterval(-24 * 60 * 60)
                return now >= service.startDate && now <= renewalThreshold && service.monthlyCost > 0.0
            }
            
            var managementList = activeServices
            if let mainName = user?.mainViewingService {
                let virtualMain = StreamingService(
                    name: "\(mainName) (Main Service)",
                    startDate: now,
                    renewalDate: Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now,
                    monthlyCost: user?.mainViewingServiceCost ?? 0.0,
                    isActive: true
                )
                managementList.append(virtualMain)
            }
            
            let allManagementServices = managementList.sorted { $0.name < $1.name }
            let (expiring, regular) = allManagementServices.partitioned { $0.renewalDate <= tenDaysFromNow }
            
            let highPriorityReady = watchlist.filter { 
                $0.status == "Ready" && 
                ($0.priority == 1 || $0.priority == 2) && 
                ($0.type == "movie" || $0.type == "episode") 
            }
            
            // 2. Binge and Regular Mappings
            var bingeMap: [StreamingService: [WatchlistItem]] = [:]
            for s in expiring {
                let sName = s.name.replacingOccurrences(of: " (Main Service)", with: "")
                let matches = highPriorityReady.filter { isServiceMatch(serviceName: sName, providers: $0.providers ?? "") }
                if !matches.isEmpty { bingeMap[s] = matches }
            }
            
            var regularMap: [StreamingService: [WatchlistItem]] = [:]
            for s in regular {
                let sName = s.name.replacingOccurrences(of: " (Main Service)", with: "")
                let matches = highPriorityReady.filter { isServiceMatch(serviceName: sName, providers: $0.providers ?? "") }
                if !matches.isEmpty { regularMap[s] = matches }
            }
            
            // 3. History Mapping
            let allWatched = watchlist.filter { $0.status == "Watched" && ($0.type == "movie" || $0.type == "episode") }
            let recentlyWatched = allWatched.filter { ($0.watchedDate ?? Date.distantPast) >= oneMonthAgo }
            
            var historyMap: [StreamingService: [WatchlistItem]] = [:]
            for s in allManagementServices {
                let sName = s.name.replacingOccurrences(of: " (Main Service)", with: "")
                let items = recentlyWatched.filter { item in
                    if let watchedOn = item.watchedOn { return isServiceMatch(serviceName: sName, providers: watchedOn) }
                    return isServiceMatch(serviceName: sName, providers: item.providers ?? "")
                }
                if !items.isEmpty { historyMap[s] = items.sorted { $0.title < $1.title } }
            }
            
            // 4. Monthly History Grouping
            struct YearMonthKey: Hashable {
                let year: Int
                let month: Int
            }

            let watchedWithComps = allWatched.compactMap { item -> (key: YearMonthKey, item: WatchlistItem)? in
                guard let date = item.watchedDate else { return nil }
                let comps = Calendar.current.dateComponents([.year, .month], from: date)
                let key = YearMonthKey(year: comps.year ?? 0, month: (comps.month ?? 1) - 1)
                return (key: key, item: item)
            }

            let grouped = watchedWithComps.groupedBy { $0.key }

            let mappedHistory: [MonthHistory] = grouped.map { key, group in
                let sortedItems = group.map { $0.item }.sorted { $0.title < $1.title }
                return MonthHistory(year: key.year, month: key.month, items: sortedItems)
            }
            let monthlyHistory = mappedHistory.sorted { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
            
            // 5. Service Status (Steady vs Change)
            let steady = allManagementServices.filter { service in
                let isMain = service.name.contains("(Main Service)")
                return !isMain && (bingeMap[service] != nil || regularMap[service] != nil || historyMap[service] != nil)
            }
            let change = allManagementServices.filter { service in
                let isMain = service.name.contains("(Main Service)")
                return !isMain && !steady.contains(service)
            }
            
            let suspendedHigh = services.filter { !$0.isActive }.filter { service in
                highPriorityReady.contains { isServiceMatch(serviceName: service.name, providers: $0.providers ?? "") }
            }
            
            // 6. Duplicates Logic
            let duplicateShows = watchlist.filter { 
                $0.status == "Ready" && ($0.priority == 1 || $0.priority == 2) && ($0.type == "movie" || $0.type == "tv") 
            }
            .compactMap { item -> (WatchlistItem, [StreamingService])? in
                let providers = item.providers ?? ""
                let matches = allManagementServices.filter { isServiceMatch(serviceName: $0.name.replacingOccurrences(of: " (Main Service)", with: ""), providers: providers) }
                return matches.count > 1 ? (item, matches) : nil
            }
            .sorted { $0.0.title < $1.0.title }
            
            var freeItemsMap: [StreamingService: [WatchlistItem]] = [:]
            let freeServices = services.filter { $0.monthlyCost == 0.0 && $0.isActive }
            for s in freeServices {
                let items = watchlist.filter { 
                    ($0.type == "movie" || $0.type == "tv") && 
                    $0.status == "Ready" && 
                    isServiceMatch(serviceName: s.name, providers: $0.providers ?? "") 
                }
                if !items.isEmpty { freeItemsMap[s] = items.sorted { $0.priority < $1.priority } }
            }
            
            // Break up the calculation to avoid compiler timeout
            let regularMins = regularMap.values.joined().compactMap { $0.runtime }.reduce(0, +)
            let bingeMins = bingeMap.values.joined().compactMap { $0.runtime }.reduce(0, +)
            let totalReadyMinutes = regularMins + bingeMins
            
            
            
            
            // 7. Optimal Timeline Logic (The "Brains")
            let subscriptionLimit = user?.concurrentSubscriptionLimit ?? 2
            let dailyHours = Double(user?.streamingHoursPerMonth ?? 60) / 30.0
            let (optimalTimeline, optimizedCost) = calculateOptimalTimeline(
                watchlist: self.watchlist,
                allServices: services,
                limit: subscriptionLimit,
                dailyHours: dailyHours
            )
            
            let totalActiveCost = services.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyCost }
            let mainServiceCost = user?.mainViewingServiceCost ?? 0.0
            let currentTotal = totalActiveCost + mainServiceCost

            self.results = AnalysisResults(
                bingeByService: bingeMap,
                regularPriorityByService: regularMap,
                historyByService: historyMap,
                steadyServices: steady,
                changeServices: change,
                suspendedHighPriority: suspendedHigh,
                highPriorityReady: highPriorityReady,
                freeItemsByService: freeItemsMap,
                duplicateShows: duplicateShows,
                monthlyHistory: monthlyHistory,
                allManagementServices: allManagementServices,
                optimalTimeline: optimalTimeline,
                totalActiveCost: currentTotal,
                optimizedCost: optimizedCost + mainServiceCost,
                totalReadyMinutes: totalReadyMinutes
            )
            
        } catch {
            print("Analysis Error: \(error)")
        }
    }

    // MARK: - Combinatorial Optimization Logic
    
    private func calculateOptimalTimeline(
        watchlist: [WatchlistItem],
        allServices: [StreamingService],
        limit: Int,
        dailyHours: Double
    ) -> (items: [TimelineItem], cost: Double) {
        let highPriorityTopLevel = watchlist.filter {
            (($0.type == "movie" && $0.status == "Ready") || $0.type == "tv") && ($0.priority == 1 || $0.priority == 2)
        }
        let mainServiceName = user?.mainViewingService
        
        // Filter services that actually have content we want
        let candidates = allServices.filter { service in
            highPriorityTopLevel.contains { isServiceMatch(serviceName: service.name, providers: $0.providers ?? "") }
        }
        
        let effectiveLimit = max(0, limit - (mainServiceName != nil ? 1 : 0))
        let combos = getCombinations(from: candidates, k: effectiveLimit)
        
        var bestCombo: [StreamingService] = []
        var maxMinutes = -1
        var minCost = Double.greatestFiniteMagnitude
        
        for combo in combos {
            var currentCombo = combo
            if let main = mainServiceName, let mainObj = allServices.first(where: { $0.name == main }) {
                currentCombo.append(mainObj)
            }
            
            let coveredTopLevel = highPriorityTopLevel.filter { item in
                currentCombo.contains { isServiceMatch(serviceName: $0.name, providers: item.providers ?? "") }
            }
            
            var currentComboMinutes = 0
            for item in coveredTopLevel {
                if item.type == "movie" {
                    currentComboMinutes += item.runtime ?? 0
                } else {
                    currentComboMinutes += watchlist.filter {
                        $0.type == "episode" && $0.parentTmdbId == item.tmdbId && $0.status == "Ready"
                    }.reduce(0) { $0 + ($1.runtime ?? 0) }
                }
            }

            let currentCost = currentCombo.reduce(0) { $0 + getProjectedCost(for: $1) }
            
            if currentComboMinutes > maxMinutes || (currentComboMinutes == maxMinutes && currentCost < minCost) {
                maxMinutes = currentComboMinutes
                minCost = currentCost
                bestCombo = currentCombo
            }
        }
        
        // Generate Timeline items from Best Combo
        var timeline: [TimelineItem] = []
        var currentDayOffset = 0.0
        
        for item in highPriorityTopLevel.sorted(by: { $0.priority < $1.priority }) {
            guard let bestService = determineBestService(item: item, availableServices: bestCombo) else { continue }
            
            let totalMinutes: Int
            if item.type == "movie" {
                totalMinutes = item.runtime ?? 0
            } else {
                totalMinutes = watchlist.filter {
                    $0.type == "episode" && $0.parentTmdbId == item.tmdbId && $0.status == "Ready"
                }.reduce(0) { $0 + ($1.runtime ?? 0) }
            }
            
            let runtime = Double(totalMinutes)
            if runtime > 0 {
                let hours = runtime / 60.0
                let daysNeeded = hours / max(0.5, dailyHours)
                let start = currentDayOffset
                let end = min(30.0, currentDayOffset + daysNeeded)
                
                if start < 30.0 {
                    timeline.append(TimelineItem(title: item.title, startDay: start, endDay: end, priority: item.priority, totalHours: hours, bestService: bestService))
                    currentDayOffset = end
                }
            }
        }
        
        return (timeline, minCost)
    }

    internal func getProjectedCost(for service: StreamingService) -> Double {
        // If the user has explicitly set a cost (even a shared one), respect it.
        if service.monthlyCost > 0 { return service.monthlyCost }
        
        // Otherwise, look for a market match.
        let name = service.name.lowercased()
        for (key, value) in marketPrices {
            if name.contains(key) { return value.cost }
        }
        
        // Generic fallback for unknown services
        return 9.99
    }

    internal func determineBestService(item: WatchlistItem, availableServices: [StreamingService]) -> String? {
        if let main = user?.mainViewingService, isServiceMatch(serviceName: main, providers: item.providers ?? "") {
            return main
        }
        return availableServices
            .filter { isServiceMatch(serviceName: $0.name, providers: item.providers ?? "") }
            .sorted { getProjectedCost(for: $0) < getProjectedCost(for: $1) }
            .first?.name
    }
    
    func isServiceMatch(serviceName: String, providers: String) -> Bool {
        let pLower = providers.lowercased()
        let sLower = serviceName.lowercased()
        
        let noise = "(\\+|plus|video|\\s|\\.|-|')"
        let pRaw = pLower.replacingOccurrences(of: noise, with: "", options: .regularExpression)
        let sRaw = sLower.replacingOccurrences(of: noise, with: "", options: .regularExpression)
        
        if sRaw.count > 2 && pRaw.contains(sRaw) { return true }
        if pRaw.count > 2 && sRaw.contains(pRaw) { return true }

        if sRaw == "appletv" && pRaw.contains("appletv") { return true }
        
        if sRaw.contains("disney") {
            if pRaw.contains("hulu") || pRaw.contains("espn") { return true }
        }
        
        return false
    }
    
    func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    func getDisplayTitle(for item: WatchlistItem, in watchlist: [WatchlistItem]) -> String {
        if item.type == "episode" {
            let show = watchlist.first { $0.type == "tv" && $0.tmdbId == item.parentTmdbId }
            let showName = show?.title ?? "Show"
            return "\(showName) S\(item.seasonNumber) E\(item.episodeNumber): \(item.title)"
        }
        return item.title
    }
    
    private func getCombinations<T>(from list: [T], k: Int) -> [[T]] {
        if k <= 0 { return [[]] }
        if k > list.count { return [list] }
        if k == list.count { return [list] }
        
        var result = [[T]]()
        func generate(_ index: Int, _ current: [T]) {
            if current.count == k {
                result.append(current)
                return
            }
            for i in index..<list.count {
                generate(i + 1, current + [list[i]])
            }
        }
        for _ in 1...k { generate(0, []) } // Check 1 through K as per Android logic
        return result.isEmpty ? [[]] : result
    }
}

extension Sequence {
    func partitioned(by belongsToFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for element in self {
            if belongsToFirst(element) { first.append(element) } else { second.append(element) }
        }
        return (first, second)
    }
    
    func groupedBy<GroupKey: Hashable>(_ keySelector: (Element) -> GroupKey) -> [GroupKey: [Element]] {
        Dictionary(grouping: self, by: keySelector)
    }
}
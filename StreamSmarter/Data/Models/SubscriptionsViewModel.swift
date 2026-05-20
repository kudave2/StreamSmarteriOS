import Foundation
import SwiftData
import Observation
import SwiftUI

@Observable
@MainActor
final class SubscriptionsViewModel {
    private var repository: StreamSmarterRepository?
    
    var services: [StreamingService] = []
    var watchlist: [WatchlistItem] = []
    var user: User?
    
    var serviceToEdit: StreamingService?
    var serviceForUrlRedirect: StreamingService?
    
    var marketServices: Set<String> = []
    
    let allServiceOptions = [
        "Amazon Prime", "Apple TV", "Crunchyroll", "Discovery+", "Disney+", "ESPN+",
        "HBO Max", "Hulu", "Netflix", "Paramount+", "Peacock", "Philo", 
        "Britbox", "Acorn TV", "AMC+", "Starz"
    ].sorted()
    
    let serviceUrls = [
        "Amazon Prime": "https://www.amazon.com/gp/video/settings",
        "Apple TV": "https://tv.apple.com/settings",
        "Crunchyroll": "https://www.crunchyroll.com/account/membership",
        "Disney+": "https://www.disneyplus.com/account",
        "HBO Max": "https://auth.max.com/account",
        "Hulu": "https://www.hulu.com/account",
        "Netflix": "https://www.netflix.com/YourAccount",
        "Paramount+": "https://www.paramountplus.com/account/",
        "Peacock": "https://www.peacocktv.com/account",
        "Starz": "https://www.starz.com/us/en/login"
    ]

    func setup(repository: StreamSmarterRepository) {
        self.repository = repository
        refreshData()
        ensureAllServicesExist()
        checkAndRotateServiceDates()
        Task {
            await syncMarketServices()
        }
    }
    
    private func ensureAllServicesExist() {
        guard let repository else { return }
        let today = Date()
        
        for serviceName in allServiceOptions {
            // Check if service already exists
            if !services.contains(where: { $0.name == serviceName }) {
                // Create with defaults: inactive, $0 cost, current date for both dates
                let newService = StreamingService(name: serviceName, startDate: today, renewalDate: today, monthlyCost: 0.0, isActive: false)
                try? repository.insertStreamingService(newService)
            }
        }
    }

    func checkAndRotateServiceDates() {
        guard let repository else { return }
        let now = Date()
        let calendar = Calendar.current
        
        for service in services where service.isActive {
            if now >= service.renewalDate {
                let newStart = service.renewalDate
                let nextRenewal = calendar.date(byAdding: .month, value: 1, to: service.renewalDate) ?? service.renewalDate
                service.startDate = newStart
                service.renewalDate = nextRenewal
                try? repository.updateStreamingService(service)
            }
        }
    }

    private func syncMarketServices() async {
        let urlString = "https://raw.githubusercontent.com/kudave2/StreamSmarterData/main/market_costs.csv"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return }
            
            let lines = csvString.components(separatedBy: .newlines)
            var servicesSet: Set<String> = []
            
            for line in lines where !line.isEmpty {
                let columns = line.components(separatedBy: ",")
                if columns.count >= 1 {
                    let serviceName = columns[0].trimmingCharacters(in: .whitespaces)
                    servicesSet.insert(serviceName)
                }
            }
            
            self.marketServices = servicesSet
        } catch {
            // Handle error, perhaps set to empty or log
        }
    }

    func refreshData() {
        guard let repository else { return }
        do {
            self.services = try repository.fetchStreamingServices()
            self.watchlist = try repository.fetchWatchlistItems()
            self.user = try repository.getUser()
        } catch {}
    }

    var sortedServices: [StreamingService] {
        let mainServiceName = user?.mainViewingService
        return services.filter { $0.name != mainServiceName }.sorted { s1, s2 in
            if s1.isActive != s2.isActive { return s1.isActive && !s2.isActive }
            if s1.renewalDate != s2.renewalDate { return s1.renewalDate > s2.renewalDate }
            return s1.name < s2.name
        }
    }

    var activeTotalCost: Double {
        let streamingCost = services.filter { $0.isActive }.reduce(0) { $1.monthlyCost + $0 }
        let mainCost = user?.mainViewingServiceCost ?? 0.0
        return streamingCost + mainCost
    }

    var expiredServices: [StreamingService] {
        let today = Calendar.current.startOfDay(for: Date())
        return services.filter { $0.isActive && $0.renewalDate < today }
    }

    func addService(name: String, start: Date, renew: Date, cost: Double, active: Bool) {
        let newService = StreamingService(name: name, startDate: start, renewalDate: renew, monthlyCost: cost, isActive: active)
        try? repository?.insertStreamingService(newService)
        refreshData()
    }

    func updateService(_ service: StreamingService, name: String, start: Date, renew: Date, cost: Double, active: Bool) {
        service.name = name
        service.startDate = start
        service.renewalDate = renew
        service.monthlyCost = cost
        
        // Enforcement: Check concurrent limit for non-premium users
        if active != service.isActive && active == true {
            let activeCount = services.filter { $0.isActive }.count
            let limit = user?.concurrentSubscriptionLimit ?? 2
            let isPremium = user?.isPremium ?? false || user?.isOverridePremium ?? false
            
            if !isPremium && activeCount >= limit {
                // TODO: Trigger upsell UI/Alert here
                return 
            }
        }

        if service.isActive != active {
            service.isActive = active
            self.serviceForUrlRedirect = service
        }
        
        try? repository?.updateStreamingService(service)
        refreshData()
    }
    
    func deleteService(_ service: StreamingService) {
        // Only allow deletion if the service is not in the market costs CSV
        guard !marketServices.contains(service.name) else { return }
        try? repository?.deleteStreamingService(service)
        refreshData()
    }


    func isServiceMatch(serviceName: String, providers: String?) -> Bool {
        guard let providers = providers else { return false }
        // Sync with Android Regex: (\\+|plus|video|\\s|\\.|-|')
        let pattern = "[\\+\\s\\.\\-' ]|plus|video"
        let pRaw = providers.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        let sRaw = serviceName.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)

        if sRaw.count > 2 && pRaw.contains(sRaw) { return true }
        if pRaw.count > 2 && sRaw.contains(pRaw) { return true }
        
        if sRaw == "appletv" && pRaw.contains("appletv") { return true }
        
        if sRaw.contains("disney") && (pRaw.contains("hulu") || pRaw.contains("espn")) { return true }
        return false
    }
}

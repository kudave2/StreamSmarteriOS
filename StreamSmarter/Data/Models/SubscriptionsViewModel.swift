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
    
    var showAddSheet: Bool = false
    var serviceToEdit: StreamingService?
    var serviceForUrlRedirect: StreamingService?
    
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
        services.sorted { s1, s2 in
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
        
        if service.isActive != active {
            service.isActive = active
            self.serviceForUrlRedirect = service
        }
        
        try? repository?.updateStreamingService(service)
        refreshData()
    }
    
    func deleteService(_ service: StreamingService) {
        try? repository?.deleteStreamingService(service)
        refreshData()
    }

    func isServiceMatch(serviceName: String, providers: String?) -> Bool {
        guard let providers = providers?.lowercased() else { return false }
        let nameLower = serviceName.lowercased()
            .replacingOccurrences(of: "+", with: " plus")
            .replacingOccurrences(of: "video", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if nameLower.contains("disney") {
            return providers.contains("disney") || providers.contains("hulu") || providers.contains("espn")
        }
        return providers.contains(nameLower)
    }
}

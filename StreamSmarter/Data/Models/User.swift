import Foundation
import SwiftData

@Model
final class User {
    var id: Int = 1
    var email: String = ""
    var concurrentSubscriptionLimit: Int = 2
    var streamingHoursPerMonth: Int = 60
    var mainViewingService: String? = nil
    var mainViewingServiceCost: Double = 0.0
    var isPremium: Bool = false
    var isOverridePremium: Bool = false
    var lastActive: Date = Date()
    var tmdbApiKey: String? = nil

    init(
        id: Int = 1,
        email: String = "",
        concurrentSubscriptionLimit: Int = 2,
        streamingHoursPerMonth: Int = 60,
        mainViewingService: String? = nil,
        mainViewingServiceCost: Double = 0.0,
        isPremium: Bool = false,
        isOverridePremium: Bool = false,
        lastActive: Date = Date(),
        tmdbApiKey: String? = nil
    ) {
        self.id = id
        self.email = email
        self.concurrentSubscriptionLimit = concurrentSubscriptionLimit
        self.streamingHoursPerMonth = streamingHoursPerMonth
        self.mainViewingService = mainViewingService
        self.mainViewingServiceCost = mainViewingServiceCost
        self.isPremium = isPremium
        self.isOverridePremium = isOverridePremium
        self.lastActive = lastActive
        self.tmdbApiKey = tmdbApiKey
    }
}

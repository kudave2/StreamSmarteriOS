import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private var repository: StreamSmarterRepository?

    var user: User?
    var activeServicesCount: Int = 0

    // Edit state — mirrors Android's local mutable state
    var tmdbApiKey: String = ""
    var streamingHoursPerMonth: String = "60"
    var concurrentSubscriptionLimit: String = "2"
    var mainViewingService: String = ""
    var mainViewingServiceCost: String = "0.00"

    // UI state
    var isValidating: Bool = false
    var showApiKeyInfo: Bool = false
    var showPremiumDialog: Bool = false
    var showValidationError: Bool = false
    var validationErrorMessage: String = ""

    var isPremiumUser: Bool {
        (user?.isPremium ?? false) || (user?.isOverridePremium ?? false)
    }

    var hasChanges: Bool {
        guard let user else { return false }
        if (Int(streamingHoursPerMonth) ?? user.streamingHoursPerMonth) != user.streamingHoursPerMonth { return true }
        if (Int(concurrentSubscriptionLimit) ?? user.concurrentSubscriptionLimit) != user.concurrentSubscriptionLimit { return true }
        if tmdbApiKey != (user.tmdbApiKey ?? "") { return true }
        if isPremiumUser {
            if mainViewingService != (user.mainViewingService ?? "") { return true }
            if (Double(mainViewingServiceCost) ?? user.mainViewingServiceCost) != user.mainViewingServiceCost { return true }
        }
        return false
    }

    func setup(repository: StreamSmarterRepository) {
        self.repository = repository
        loadData()
    }

    func loadData() {
        guard let repository else { return }
        do {
            if let existing = try repository.getUser() {
                user = existing
            } else {
                let newUser = User()
                try repository.saveUser(newUser)
                user = newUser
            }
            if let user {
                tmdbApiKey = user.tmdbApiKey ?? ""
                streamingHoursPerMonth = String(user.streamingHoursPerMonth)
                concurrentSubscriptionLimit = String(user.concurrentSubscriptionLimit)
                mainViewingService = user.mainViewingService ?? ""
                mainViewingServiceCost = String(format: "%.2f", user.mainViewingServiceCost)
            }
            let services = try repository.fetchStreamingServices()
            let now = Date()
            activeServicesCount = services.filter {
                $0.isActive || now < $0.renewalDate
            }.count
        } catch {}
    }

    func updateProfile() async {
        guard let repository else { return }
        isValidating = true

        let key = tmdbApiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty {
            let valid = await repository.validateTmdbApiKey(key)
            if !valid {
                isValidating = false
                showValidationError = true
                validationErrorMessage = "Invalid TMDB API key. Please check and try again."
                return
            }
        }

        do {
            try repository.updateUser { user in
                user.tmdbApiKey = key.isEmpty ? nil : key
                user.streamingHoursPerMonth = Int(self.streamingHoursPerMonth) ?? user.streamingHoursPerMonth
                user.concurrentSubscriptionLimit = Int(self.concurrentSubscriptionLimit) ?? user.concurrentSubscriptionLimit
                if self.isPremiumUser {
                    user.mainViewingService = self.mainViewingService.isEmpty ? nil : self.mainViewingService
                    user.mainViewingServiceCost = Double(self.mainViewingServiceCost) ?? user.mainViewingServiceCost
                }
                user.lastActive = Date()
            }
            self.user = try repository.getUser()
        } catch {}

        isValidating = false
    }

    func toggleOverridePremium() {
        guard let repository else { return }
        do {
            try repository.updateUser { user in user.isOverridePremium.toggle() }
            self.user = try repository.getUser()
        } catch {}
    }

    func attemptPremiumUpgrade() async {
        let key = tmdbApiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            showValidationError = true
            validationErrorMessage = "Please obtain a TMDB API key on the Profile screen before obtaining premium service. We want you up and running with the most functionality possible!"
            return
        }
        isValidating = true
        let valid = await repository?.validateTmdbApiKey(key) ?? false
        isValidating = false
        if valid {
            showPremiumDialog = true
        } else {
            showValidationError = true
            validationErrorMessage = "Invalid TMDB API key. Please check and try again."
        }
    }
}

import Foundation

struct MonthHistory: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let items: [WatchlistItem]
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month + 1
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }
}

struct TimelineItem: Identifiable {
    let id = UUID()
    let title: String
    let startDay: Double
    let endDay: Double
    let priority: Int
    let totalHours: Double
    let bestService: String?
}

struct AnalysisResults {
    var bingeByService: [StreamingService: [WatchlistItem]] = [:]
    var regularPriorityByService: [StreamingService: [WatchlistItem]] = [:]
    var historyByService: [StreamingService: [WatchlistItem]] = [:]
    var steadyServices: [StreamingService] = []
    var changeServices: [StreamingService] = []
    var suspendedHighPriority: [StreamingService] = []
    var highPriorityReady: [WatchlistItem] = []
    var freeItemsByService: [StreamingService: [WatchlistItem]] = [:]
    var duplicateShows: [(WatchlistItem, [StreamingService])] = []
    var monthlyHistory: [MonthHistory] = []
    var allManagementServices: [StreamingService] = []
    var optimalTimeline: [TimelineItem] = []
    var totalActiveCost: Double = 0.0
    var optimizedCost: Double = 0.0
    var totalReadyMinutes: Int = 0
}
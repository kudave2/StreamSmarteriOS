import Foundation
import SwiftData

@Model
final class StreamingService {
    var name: String
    var startDate: Date
    var renewalDate: Date
    var monthlyCost: Double = 0.0
    var isActive: Bool = true

    init(
        name: String,
        startDate: Date,
        renewalDate: Date,
        monthlyCost: Double = 0.0,
        isActive: Bool = true
    ) {
        self.name = name
        self.startDate = startDate
        self.renewalDate = renewalDate
        self.monthlyCost = monthlyCost
        self.isActive = isActive
    }
}

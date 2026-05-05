import Foundation
import SwiftData

@Model
final class AppNotification {
    var title: String
    var message: String
    var timestamp: Date
    var type: String
    var isRead: Bool

    init(
        title: String,
        message: String,
        timestamp: Date = Date(),
        type: String = "RENEWAL",
        isRead: Bool = false
    ) {
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.type = type
        self.isRead = isRead
    }
}

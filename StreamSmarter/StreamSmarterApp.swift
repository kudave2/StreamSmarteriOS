import SwiftUI
import SwiftData

@main
struct StreamSmarterApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            WatchlistItem.self,
            StreamingService.self,
            AppNotification.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}


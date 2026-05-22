import SwiftUI
import SwiftData

@main
struct StreamSmarterApp: App {
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode = true

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
            if isOnboardingComplete {
                ContentView()
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

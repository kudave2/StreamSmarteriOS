import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("isDarkMode") private var isDarkMode = true

    // Navigation paths for each tab to enable programmatic popping to root
    @State private var watchlistPath = NavigationPath()
    @State private var subscriptionsPath = NavigationPath()
    @State private var analysisPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                // When switching tabs, clear all paths to "back out" of sub-screens like HelpView
                if newValue != selectedTab {
                    watchlistPath = NavigationPath()
                    subscriptionsPath = NavigationPath()
                    analysisPath = NavigationPath()
                    profilePath = NavigationPath()
                }
                selectedTab = newValue
            }
        )) {
            // First Tab with a NavigationStack
            NavigationStack(path: $watchlistPath) {
                WatchlistView()
                    .navigationDestination(for: String.self) { value in
                        if value == "help" { HelpView() }
                    }
            }
            .tabItem {
                Label("Watchlist", systemImage: "eyes")
            }
            .tag(0)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
            
            // Second Tab (Simple Profile Placeholder)
            NavigationStack(path: $subscriptionsPath) {
                SubscriptionsView()
                    .navigationDestination(for: String.self) { value in
                        if value == "help" { HelpView() }
                    }
            }
            .tabItem {
                Label("Subscriptions", systemImage: "ticket.fill")
            }
            .tag(1)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
            
            NavigationStack(path: $analysisPath) {
                AnalysisView()
                    .navigationDestination(for: String.self) { value in
                        if value == "help" { HelpView() }
                    }
            }
            .tabItem {
                Label("Analysis", systemImage: "brain.fill")
            }
            .tag(2)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
            
            NavigationStack(path: $profilePath) {
                ProfileView()
                    .navigationDestination(for: String.self) { value in
                        if value == "help" { HelpView() }
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
        }
        .animation(nil, value: selectedTab)
        .tint(isDarkMode ? .ssPrimary : .ssSecondary)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}


// MARK: - Component Views

struct HomeView: View {
    var body: some View {
        List(1...20, id: \.self) { item in
            NavigationLink(value: item) {
                Text("List Item \(item)")
            }
        }
        .navigationDestination(for: Int.self) { item in
            DetailView(itemNumber: item)
        }
    }
}

struct DetailView: View {
    let itemNumber: Int
    
    var body: some View {
        VStack {
            Text("Detail View for Item \(itemNumber)")
                .font(.title)
        }
        .navigationTitle("Item \(itemNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }


    
    private func menuButton(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(.headline)
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.lightGreen.opacity(0.8))
        .cornerRadius(10)
    }
}


#Preview {
    ContentView()
}

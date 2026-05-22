import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        TabView {
            // First Tab with a NavigationStack
            NavigationStack {
                WatchlistView()
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
            NavigationStack {
                SubscriptionsView()
            }
            .tabItem {
                Label("Subscriptions", systemImage: "ticket.fill")
            }
            .tag(1)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
            
            NavigationStack {
                AnalysisView()
            }
            .tabItem {
                Label("Analysis", systemImage: "brain.fill")
            }
            .tag(2)
            // 1. Applies the opaque orange color to this tab bar state
            .toolbarBackground(Color.orange, for: .tabBar)
            // 2. Forces it to remain visible/opaque even when scrolling
            .toolbarBackground(.visible, for: .tabBar)
            
            NavigationStack {
                ProfileView()
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

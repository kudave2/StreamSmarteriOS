import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchlistView()
            }
            .tabItem {
                Label("Watchlist", systemImage: "eyes")
            }
            
            NavigationStack {
                SubscriptionsView()
            }
            .tabItem {
                Label("Subscriptions", systemImage: "ticket.fill")
            }
            
            NavigationStack {
                AnalysisView()
            }
            .tabItem {
                Label("Analysis", systemImage: "brain.fill")
            }
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .tint(.accentYellow)
        .preferredColorScheme(.light)
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
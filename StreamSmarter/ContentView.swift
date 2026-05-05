import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Welcome to StreamSmarter")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    NavigationLink {
                        SubscriptionsView()
                    } label: {
                        menuButton(title: "Subscriptions", icon: "creditcard.fill")
                    }
                    
                    NavigationLink {
                        WatchlistView()
                    } label: {
                        menuButton(title: "Watchlist", icon: "play.tv.fill")
                    }
                    
                    NavigationLink {
                        ProfileView()
                    } label: {
                        menuButton(title: "Profile", icon: "person.fill")
                    }

                    NavigationLink {
                        AnalysisView()
                    } label: {
                        menuButton(title: "Analysis", icon: "chart.pie.fill")
                    }

                    NavigationLink {
                        HelpView()
                    } label: {
                        menuButton(title: "Help & Support", icon: "questionmark.circle.fill")
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("StreamSmarter")
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StreamSmarterLogoView(
                        iconSize: 22,
                        fontSize: 20,
                        taglineSize: 6
                    )
                }
            }
            .background(Color.black)
        }
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
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section: Application Purpose
                VStack(alignment: .leading, spacing: 8) {
                    Text("Application Purpose")
                        .font(.title2.bold())
                        .foregroundColor(.ssSecondary)
                        .padding(.top, 2)
                    
                    Text("StreamSmarter helps you manage your streaming subscriptions effectively. By tracking your watchlist and viewing habits, the app provides data-driven recommendations on which services to keep active and which to suspend, saving you money while ensuring you always have high-priority content ready to watch.")
                        .font(.body)
                        .foregroundColor(.ssText)
                        .lineSpacing(4)
                }

                // Section: Steps to Get Started
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steps to Get Started")
                        .font(.title2.bold())
                        .foregroundColor(.ssSecondary)
                        .padding(.vertical, 2)

                    helpStep(
                        number: 1,
                        title: "Configure Your Profile",
                        description: "Go to the Profile screen to set your Main Service, desired monthly spending limit, and average streaming hours per month."
                    )
                    helpStep(
                        number: 2,
                        title: "Manage Streaming Services",
                        description: "On the Services screen, add your subscriptions with their renewal dates and costs. When you activate or suspend a service, StreamSmarter can take you directly to that service's website to manage your account."
                    )
                    helpStep(
                        number: 3,
                        title: "Build Your Watchlist",
                        description: "Search for and add movies or TV shows. Assign a priority from 1 (Must Watch) to 3 (Watch Later). Expanding a TV season card will automatically fetch episode descriptions and runtimes for you."
                    )
                    helpStep(
                        number: 4,
                        title: "Track Your Progress",
                        description: "Mark items as 'Watched' as you finish them. This keeps your history accurate for the analyzer and helps identify which services are providing the best value."
                    )
                    helpStep(
                        number: 5,
                        title: "Analyze and Save",
                        description: "Visit the Analysis screen for a Summary of your savings and watching timeline. Use 'Deep Dive Analytics' buttons to explore binging opportunities, history trends, and options to optimize your spending."
                    )
                    helpStep(
                        number: 6,
                        title: "Stay Updated",
                        description: "Tap the bell icon on individual TV shows to flag them for notifications. You will receive alerts 1 and 2 days before new seasons or episodes air. The app monitors for these dates in the background automatically."
                    )
                }

                // Section: The Goal
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Goal")
                        .font(.title2.bold())
                        .foregroundColor(.ssSecondary)
                    
                    Text("The ultimate goal is to keep your 'Active Services' aligned with your 'Priority Watchlist' while minimizing cost. Happy streaming!")
                        .font(.callout)
                        .foregroundColor(.ssText)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.ssBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 253/255, green: 253/255, blue: 253/255), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                StreamSmarterLogoView(
                    iconSize: 24,
                    fontSize: 24,
                    taglineSize: 8
                )
                .environment(\.colorScheme, .light)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private func helpStep(number: Int, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundColor(.ssText)
                .fontWeight(.bold)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.ssText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
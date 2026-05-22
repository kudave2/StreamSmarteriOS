import SwiftUI

struct HistoryTrendsView: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            Color.ssBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Standard Title Row with Help Icon
                HStack(alignment: .center, spacing: 12) {
                    Text("History Trends")
                        .font(.title.bold())
                        .foregroundColor(.ssSecondary)
                    
                    Spacer()

                    NavigationLink {
                        HelpView()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Monthly Watched History Card
                        MonthlyHistoryTableCard(
                            monthlyHistory: data.monthlyHistory,
                            watchlist: viewModel.watchlist,
                            viewModel: viewModel
                        )
                        
                        // 2. Available on Main Service & Others Section
                        MainServiceDuplicatesCard(
                            user: user,
                            data: data,
                            watchlist: viewModel.watchlist,
                            viewModel: viewModel
                        )
                        
                        // 3. Shows on Multiple Active Services Section
                        MultipleActiveServiceShowsCard(
                            data: data,
                            viewModel: viewModel
                        )
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                StreamSmarterLogoView(
                    iconSize: 24,
                    fontSize: 24,
                    taglineSize: 8
                )
            }
        }
        .toolbarBackground(Color.ssBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
import SwiftUI
import SwiftData

struct HistoryTrendsView: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RecentWatchAuditCard(watchlist: viewModel.watchlist, viewModel: viewModel)
                
                if !data.historyByService.isEmpty {
                    Text("Watched History by Service")
                        .font(.headline.bold())
                        .foregroundColor(.popcornYellow)
                        .padding(.top, 10)
                    
                    ForEach(data.historyByService.keys.sorted(by: { $0.name < $1.name })) { service in
                        if let items = data.historyByService[service], !items.isEmpty {
                            ServiceHistoryCard(service: service, items: items, watchlist: viewModel.watchlist, viewModel: viewModel)
                        }
                    }
                }
                
                if !data.monthlyHistory.isEmpty {
                    Text("Monthly Watched History")
                        .font(.headline.bold())
                        .foregroundColor(.popcornYellow)
                        .padding(.top, 10)
                    MonthlyHistoryTableCard(monthlyHistory: data.monthlyHistory, watchlist: viewModel.watchlist, viewModel: viewModel)
                }
            }
            .padding()
        }
        .navigationTitle("History Trends")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
    }
}
import SwiftUI
import SwiftData

struct ServiceUtilizationView: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("High Priority Shows on Active Services")
                    .font(.title2.bold())
                    .foregroundColor(.accentYellow)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let activeServices = (data.steadyServices + data.changeServices).unique(by: \.id).sorted(by: { $0.name < $1.name })
                
                if activeServices.isEmpty {
                    Text("No active services with high priority shows found.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(activeServices) { service in
                        let bingeItems = data.bingeByService[service] ?? []
                        let regularItems = data.regularPriorityByService[service] ?? []
                        let allItems = (bingeItems + regularItems).unique(by: \.id)
                        
                        if !allItems.isEmpty {
                            HighPriorityServiceCard(service: service, items: allItems, allWatchlist: viewModel.watchlist, accentColor: .brandBlue, viewModel: viewModel)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("High Priority Active")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
    }
}
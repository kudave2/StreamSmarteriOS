import SwiftUI
import SwiftData

struct BingingOpportunitiesView: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Let's Binge!")
                    .font(.title2.bold())
                    .foregroundColor(.ssPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let bingeServices = data.bingeByService.keys.sorted(by: { $0.name < $1.name })
                
                if bingeServices.isEmpty {
                    Text("No binging opportunities found for your active services.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(bingeServices) { service in
                        if let items = data.bingeByService[service], !items.isEmpty {
                            HighPriorityServiceCard(service: service, items: items, allWatchlist: viewModel.watchlist, accentColor: .green, viewModel: viewModel)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Binging Opportunities")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.ssBackground.ignoresSafeArea())
        .toolbarBackground(Color.ssBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
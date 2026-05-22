import SwiftUI
import SwiftData

struct OptimizationOptionsView: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Options to Consider")
                    .font(.title2.bold())
                    .foregroundColor(.ssPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                SummaryCard(user: user, data: data, viewModel: viewModel)
                WindsOfChangeCard(user: user, data: data, watchlist: viewModel.watchlist, viewModel: viewModel)
                DetoxCard(data: data, watchlist: viewModel.watchlist, viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("Options to Consider")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.ssBackground.ignoresSafeArea())
        .toolbarBackground(Color.ssBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDarkMode ? .dark : .light, for: .navigationBar)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AnalysisViewModel()
    @State private var currentView: String = "Summary"
    
    var body: some View {
        VStack(spacing: 0) {
            if currentView == "Summary" {
                summaryHeader
            } else {
                deepDiveHeader
            }

            ScrollView {
                VStack(spacing: 16) {
                    if let results = viewModel.results {
                        switch currentView {
                        case "Summary":
                            summaryDashboard(results)
                        case "Let's Binge!":
                            bingeDeepDive(results)
                        case "High Priority Active":
                            activeDeepDive(results)
                        case "History / Good to Know":
                            historyDeepDive(results)
                        case "Options to Consider":
                            optionsDeepDive(results)
                        default:
                            EmptyView()
                        }
                    } else {
                        ContentUnavailableView("No Data Available", systemImage: "chart.bar.xaxis", description: Text("Add items to your watchlist and services to see analysis."))
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .navigationTitle(currentView == "Summary" ? "Analysis" : currentView)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                StreamSmarterLogoView(
                    iconSize: 32,
                    fontSize: 32,
                    taglineSize: 10
                )
            }
        }
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Summary")
                .font(.largeTitle.bold())
                .foregroundColor(.brandBlue)

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
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var deepDiveHeader: some View {
        HStack {
            Button { currentView = "Summary" } label: {
                Text("Back")
                    .foregroundColor(.brandBlue)
            }
            Text(currentView)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func summaryDashboard(_ results: AnalysisResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // First Glance Card
            FirstGlanceCard(user: viewModel.user, data: results, viewModel: viewModel)
            
            // Optimal Timeline Card
            OptimalTimelineCard(user: viewModel.user, data: results, viewModel: viewModel)
            
            // Project Timeline Card
            ProjectTimelineCard(user: viewModel.user, data: results, viewModel: viewModel)
            
            // Show Availability Matrix Card
            ShowAvailabilityMatrixCard(user: viewModel.user, data: results, viewModel: viewModel)
            
            Text("Deep Dive Analytics")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                deepDiveButton(title: "Let's Binge!", subtitle: "\(results.bingeByService.count) services expiring soon", color: .orange)
                deepDiveButton(title: "High Priority Active", subtitle: "\(results.highPriorityReady.count) shows ready to watch", color: .green)
                deepDiveButton(title: "History / Good to Know", subtitle: "\(results.monthlyHistory.count) months of data", color: .yellow)
                deepDiveButton(title: "Options to Consider", subtitle: "Service change recommendations", color: .brandBlue)
            }
        }
    }

    private func deepDiveButton(title: String, subtitle: String, color: Color) -> some View {
        Button { currentView = title } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(color)
                    Text(subtitle).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(color)
            }
            .padding()
            .background(Color.retroGray)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
        }
    }

    private func bingeDeepDive(_ results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            if results.bingeByService.isEmpty {
                Text("No services expiring within 10 days with high priority content.").foregroundColor(.gray).padding()
            } else {
                ForEach(results.bingeByService.keys.sorted(by: { $0.name < $1.name })) { service in
                    HighPriorityServiceCard(
                        service: service,
                        items: results.bingeByService[service] ?? [],
                        allWatchlist: viewModel.watchlist,
                        accentColor: .orange,
                        viewModel: viewModel
                    )
                }
            }
        }
    }

    private func activeDeepDive(_ results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            ForEach(results.regularPriorityByService.keys.sorted(by: { $0.name < $1.name })) { service in
                HighPriorityServiceCard(
                    service: service,
                    items: results.regularPriorityByService[service] ?? [],
                    allWatchlist: viewModel.watchlist,
                    accentColor: .green,
                    viewModel: viewModel
                )
            }
        }
    }

    private func historyDeepDive(_ results: AnalysisResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RecentWatchAuditCard(watchlist: viewModel.watchlist, viewModel: viewModel)
            
            if !results.historyByService.isEmpty {
                Text("Watch History by Service (Last 30 Days)")
                    .font(.caption.bold()).foregroundColor(.popcornYellow).padding(.leading, 4)
                
                ForEach(results.historyByService.keys.sorted(by: { $0.name < $1.name })) { service in
                    ServiceHistoryCard(service: service, items: results.historyByService[service] ?? [], watchlist: viewModel.watchlist, viewModel: viewModel)
                }
            }
            
            if !results.monthlyHistory.isEmpty {
                Text("Monthly Watch History").font(.caption.bold()).foregroundColor(.white).padding(.leading, 4)
                MonthlyHistoryTableCard(monthlyHistory: results.monthlyHistory, watchlist: viewModel.watchlist, viewModel: viewModel)
            }
            
            MainServiceDuplicatesCard(user: viewModel.user, data: results, watchlist: viewModel.watchlist, viewModel: viewModel)
            
            if !results.duplicateShows.isEmpty {
                Text("Shows on Multiple Active Services").font(.caption.bold()).foregroundColor(.popcornYellow).padding(.leading, 4)
                ForEach(results.duplicateShows, id: \.0.id) { (show, providers) in
                    DuplicateShowCard(showTitle: show.title, providerList: providers.map { $0.name }.joined(separator: ", "))
                }
            }
        }
    }

    private func optionsDeepDive(_ results: AnalysisResults) -> some View {
        VStack(spacing: 16) {
            SummaryCard(user: viewModel.user, data: results, viewModel: viewModel)
            WindsOfChangeCard(user: viewModel.user, data: results, watchlist: viewModel.watchlist, viewModel: viewModel)
            DetoxCard(data: results, watchlist: viewModel.watchlist, viewModel: viewModel)
        }
    }
}

#Preview {
    AnalysisView()
}
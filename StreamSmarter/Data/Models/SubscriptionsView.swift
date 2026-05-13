import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SubscriptionsViewModel()
    @State private var analysisViewModel = AnalysisViewModel()
    @State private var showWebsiteDialog = false
    
    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("Subscriptions")
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Monthly Cost: \(viewModel.activeTotalCost.formatted(.currency(code: "USD")))")
                    .font(.headline)
                    .foregroundColor(.accentYellow)
                
                Text("Any service you \"share\" or is free, set cost < $0.99 for better analysis.")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.gray)
            }
            .padding()

            if !viewModel.expiredServices.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Action Required: \(viewModel.expiredServices.count) past renewal.")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            List {
                if let mainName = viewModel.user?.mainViewingService {
                    MainServiceRow(
                        name: mainName,
                        cost: viewModel.user?.mainViewingServiceCost ?? 0.0,
                        watchlist: viewModel.watchlist,
                        matcher: viewModel.isServiceMatch
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                ForEach(viewModel.sortedServices) { service in
                    ServiceRow(
                        service: service,
                        watchlist: viewModel.watchlist,
                        matcher: viewModel.isServiceMatch,
                        analysisViewModel: analysisViewModel,
                        marketServices: viewModel.marketServices,
                        onEdit: {
                            viewModel.serviceToEdit = service
                        },
                        onDelete: {
                            viewModel.deleteService(service)
                        }
                    )
                }
                .onDelete(perform: deleteService)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)
        }
        .background(Color.black)
        .navigationTitle("Subscriptions")
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
            analysisViewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
        .sheet(item: $viewModel.serviceToEdit) { service in
            ServiceEditSheet(viewModel: viewModel, service: service)
        }
        .onChange(of: viewModel.serviceForUrlRedirect) { oldValue, newValue in
            showWebsiteDialog = newValue != nil
        }
        .overlay(alignment: .center) {
            if showWebsiteDialog, let service = viewModel.serviceForUrlRedirect {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showWebsiteDialog = false
                            viewModel.serviceForUrlRedirect = nil
                        }
                    
                    VStack(spacing: 16) {
                        Text("Visit Website?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("You've changed the status of \(service.name). Would you like to visit their site?")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                showWebsiteDialog = false
                                viewModel.serviceForUrlRedirect = nil
                            }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundColor(.accentYellow)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentYellow, lineWidth: 1))
                            }
                            
                            Button(action: {
                                if let urlString = viewModel.serviceUrls[service.name], let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                                showWebsiteDialog = false
                                viewModel.serviceForUrlRedirect = nil
                            }) {
                                Text("Visit Site")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundColor(.black)
                                    .background(Color.accentYellow)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .background(Color.retroGray)
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
    
    private func deleteService(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteService(viewModel.sortedServices[index])
        }
    }
}

#Preview("Subscriptions View") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema([User.self, WatchlistItem.self, StreamingService.self, AppNotification.self]), configurations: config)

        // Add a sample user
        let user = User(mainViewingService: "Netflix", mainViewingServiceCost: 15.99, isPremium: true)
        container.mainContext.insert(user)

        // Add some sample streaming services
        let netflix = StreamingService(name: "Netflix", startDate: Date().addingTimeInterval(-365*24*60*60), renewalDate: Date().addingTimeInterval(30*24*60*60), monthlyCost: 15.99, isActive: true)
        container.mainContext.insert(netflix)

        let hulu = StreamingService(name: "Hulu", startDate: Date().addingTimeInterval(-180*24*60*60), renewalDate: Date().addingTimeInterval(15*24*60*60), monthlyCost: 12.99, isActive: true)
        container.mainContext.insert(hulu)

        let disneyPlus = StreamingService(name: "Disney+", startDate: Date().addingTimeInterval(-90*24*60*60), renewalDate: Date().addingTimeInterval(-5*24*60*60), monthlyCost: 7.99, isActive: true) // Expired service
        container.mainContext.insert(disneyPlus)

        let prime = StreamingService(name: "Amazon Prime", startDate: Date().addingTimeInterval(-60*24*60*60), renewalDate: Date().addingTimeInterval(60*24*60*60), monthlyCost: 0.50, isActive: true) // Shared/Free
        container.mainContext.insert(prime)
        
        let max = StreamingService(name: "HBO Max", startDate: Date().addingTimeInterval(-200*24*60*60), renewalDate: Date().addingTimeInterval(45*24*60*60), monthlyCost: 16.99, isActive: false) // Suspended service
        container.mainContext.insert(max)

        // Add some sample watchlist items
        let watchlist1 = WatchlistItem(title: "The Crown", type: "tv", priority: 1, providers: "Netflix")
        container.mainContext.insert(watchlist1)
        let watchlist2 = WatchlistItem(title: "Mandalorian", type: "tv", priority: 2, providers: "Disney+")
        container.mainContext.insert(watchlist2)
        let watchlist3 = WatchlistItem(title: "Reacher", type: "tv", priority: 3, providers: "Amazon Prime")
        container.mainContext.insert(watchlist3)

        return SubscriptionsView()
            .modelContainer(container)
    } catch {
        fatalError("Failed to create ModelContainer for preview: \(error)")
    }
}

// Row Components
struct MainServiceRow: View {
    let name: String
    let cost: Double
    let watchlist: [WatchlistItem]
    let matcher: (String, String?) -> Bool
    
    var availableItems: [WatchlistItem] {
        watchlist.filter {
            ($0.type == "tv" || $0.type == "movie") && matcher(name, $0.providers)
        }.sorted(by: { $0.priority < $1.priority })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name).font(.headline).bold().foregroundColor(.white)
                    Text("Main Service").font(.caption).foregroundColor(.accentYellow)
                }
                Spacer()
                Text(cost.formatted(.currency(code: "USD"))).foregroundColor(.accentYellow)
            }
        }
        .padding()
        .background(Color.retroGray)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentYellow, lineWidth: 1))
    }
}

struct ServiceRow: View {
    let service: StreamingService
    let watchlist: [WatchlistItem]
    let matcher: (String, String?) -> Bool
    let analysisViewModel: AnalysisViewModel
    let marketServices: Set<String>
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var isNotActivated: Bool {
        return service.monthlyCost == 0.0 && !service.isActive
    }
    
    var isSharedOrFree: Bool {
        return service.monthlyCost > 0.0 && service.monthlyCost < 1.0
    }
    
    var statusText: String {
        if isNotActivated { return "Not Activated" }
        if isSharedOrFree {
            return "Shared/Free"
        }
        return service.isActive ? "Active" : "Suspended"
    }
    
    var statusColor: Color {
        if isNotActivated { return .gray }
        if isSharedOrFree {
            return .orange
        }
        return service.isActive ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(service.name).font(.headline).bold()
                        .foregroundColor(service.isActive || isSharedOrFree ? .white : .gray)
                    Text(statusText)
                        .font(.caption).foregroundColor(statusColor)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onEdit()
                }
                Spacer()
                if !marketServices.contains(service.name) {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash.circle").foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle").foregroundColor(.accentYellow)
                }
                .buttonStyle(.plain)
            }
            
            HStack {
                if isNotActivated {
                    let mktCost = analysisViewModel.getProjectedCost(for: service)
                    Text("Mkt: \(mktCost.formatted(.currency(code: "USD")))")
                        .foregroundColor(.gray)
                } else {
                    Text(service.monthlyCost.formatted(.currency(code: "USD"))).foregroundColor(.accentYellow)
                }
                Spacer()
                Text("Renews: \(service.renewalDate, style: .date)").font(.caption).foregroundColor(.brandBlue)
            }
        }
        .padding()
        .background((service.isActive || isSharedOrFree) ? Color.retroGray : Color(white: 0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke((service.isActive || isSharedOrFree) ? Color.accentYellow : Color.gray.opacity(0.3), lineWidth: 1))
        .alert("Delete Service", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(service.name)? This action cannot be undone.")
        }
    }
}

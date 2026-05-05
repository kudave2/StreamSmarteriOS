import SwiftUI
import SwiftData

private let accentYellow = Color(red: 1.0, green: 0.84, blue: 0.0)
private let retroGray = Color(white: 0.12)

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SubscriptionsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Monthly Cost: $\(String(format: "%.2f", viewModel.activeTotalCost))")
                    .font(.headline)
                    .foregroundColor(accentYellow)
                
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
                        matcher: viewModel.isServiceMatch
                    ) {
                        viewModel.serviceToEdit = service
                    }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(accentYellow)
                }
            }
        }
        .onAppear {
            viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            ServiceEditSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.serviceToEdit) { service in
            ServiceEditSheet(viewModel: viewModel, service: service)
        }
        .alert("Visit Website?", item: $viewModel.serviceForUrlRedirect) { service in
            Button("Yes, Go There") {
                if let urlString = viewModel.serviceUrls[service.name], let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("No, Thanks", role: .cancel) { }
        } message: { service in
            Text("You've changed the status of \(service.name). Would you like to visit their site?")
        }
    }
    
    private func deleteService(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteService(viewModel.sortedServices[index])
        }
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
                    Text("Main Service").font(.caption).foregroundColor(accentYellow)
                }
                Spacer()
                Text("$\(String(format: "%.2f", cost))").foregroundColor(accentYellow)
            }
        }
        .padding()
        .background(retroGray)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentYellow, lineWidth: 1))
    }
}

struct ServiceRow: View {
    let service: StreamingService
    let watchlist: [WatchlistItem]
    let matcher: (String, String?) -> Bool
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(service.name).font(.headline).bold()
                        .foregroundColor(service.isActive ? .white : .gray)
                    Text(service.isActive ? "Active" : "Suspended")
                        .font(.caption).foregroundColor(service.isActive ? .green : .red)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle").foregroundColor(accentYellow)
                }
            }
            
            HStack {
                Text("$\(String(format: "%.2f", service.monthlyCost))").foregroundColor(accentYellow)
                Spacer()
                Text("Renews: \(service.renewalDate, style: .date)").font(.caption).foregroundColor(.cyan)
            }
        }
        .padding()
        .background(service.isActive ? retroGray : Color(white: 0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(service.isActive ? accentYellow : Color.gray.opacity(0.3), lineWidth: 1))
    }
}

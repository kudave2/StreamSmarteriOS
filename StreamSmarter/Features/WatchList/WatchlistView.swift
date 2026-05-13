import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WatchlistViewModel()
    @State private var itemToEdit: WatchlistItem?
    @State private var showDeleteConfirmation: WatchlistItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Search Area
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Watchlist")
                        .font(.largeTitle.bold())
                        .foregroundColor(.brandBlue)
                    
                    TmdbLogoView()
                        .frame(height: 18)
                    
                    Spacer()

                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(.brandBlue)
                    }

                    NavigationLink {
                        HelpView()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                
                if let total = viewModel.user?.mainViewingServiceCost {
                    Text("Current Monthly Cost: \(total.formatted(.currency(code: "USD")))")
                        .font(.headline)
                        .foregroundColor(.accentYellow)
                }
                
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search watchlist...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color.retroGray)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.black)

            // Main List
            List {
                if viewModel.currentTabItems.isEmpty {
                    ContentUnavailableView(
                        "No Items Found",
                        systemImage: "tv.slash",
                        description: Text("Try searching for something new or check another tab.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.currentTabItems, content: watchlistRow)
            }
            .listStyle(.plain)
            .background(Color.black)

            // Custom Tab Bar
            HStack(spacing: 0) {
                tabButton(title: "Available", tab: .available)
                tabButton(title: "Unavailable", tab: .unavailable)
                tabButton(title: "Watched", tab: .watched)
            }
            .padding(.bottom, 20)
            .background(Color.retroGray)
        }
        .navigationTitle("Watchlist")
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
        .background(Color.black)
        .onAppear {
            viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddWatchlistView(viewModel: viewModel)
        }
        .sheet(item: $itemToEdit) { item in
            PriorityEditSheet(item: item) { newPriority in
                item.priority = newPriority
                viewModel.refreshData()
            }
            .presentationDetents([.height(250)])
        }
        .alert("Delete Item?", isPresented: Binding(get: { showDeleteConfirmation != nil }, set: { if !$0 { showDeleteConfirmation = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let item = showDeleteConfirmation {
                    viewModel.deleteHierarchy(item)
                }
            }
        } message: {
            Text("This will permanently remove '\(showDeleteConfirmation?.title ?? "")' and its related content.")
        }
    }
    
    @ViewBuilder
    private func watchlistRow(_ item: WatchlistItem) -> some View {
        HierarchicalWatchlistRow(
            item: item,
            allItems: viewModel.allItems,
            onStatusToggle: { toggledItem, updatedStatus in
                viewModel.updateHierarchyStatus(toggledItem, newStatus: updatedStatus)
            },
            onEdit: { clickedItem in itemToEdit = clickedItem },
            onDelete: { itemToDelete in showDeleteConfirmation = itemToDelete },
            onToggleNotifications: { itemToFlag in viewModel.toggleNotificationFlag(for: itemToFlag) }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { viewModel.deleteHierarchy(item) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { itemToEdit = item } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func tabButton(title: String, tab: WatchlistTab) -> some View {
        Button {
            viewModel.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(viewModel.selectedTab == tab ? .green : .gray)
                if viewModel.selectedTab == tab {
                    Rectangle()
                        .frame(width: 20, height: 2)
                        .foregroundColor(.accentYellow)
                } else {
                    Spacer().frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

/// A SwiftUI implementation of the TMDB logo to handle cases where the 
/// original asset is an Android XML VectorDrawable.
struct TmdbLogoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1/255, green: 180/255, blue: 228/255), // TMDB Teal
                        Color(red: 144/255, green: 206/255, blue: 161/255) // TMDB Light Green
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            Text("TMDb")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white)
                .italic()
                .padding(.horizontal, 6)
        }
        .fixedSize()
    }
}

struct HierarchicalWatchlistRow: View {
    let item: WatchlistItem
    let allItems: [WatchlistItem]
    let onStatusToggle: (WatchlistItem, String) -> Void
    let onEdit: (WatchlistItem) -> Void
    let onDelete: (WatchlistItem) -> Void
    let onToggleNotifications: (WatchlistItem) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 2) {
            Group {
                HStack(alignment: .center) {
                    // Tappable area for expansion
                    Button {
                        if item.type == "tv" { isExpanded.toggle() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline).bold().foregroundColor(.black)
                                Text("\(item.type.uppercased()) • Priority: \(priorityLabel)")
                                    .font(.caption).foregroundColor(.black.opacity(0.7))
                                
                                if item.status == "Watched", let watchedOn = item.watchedOn {
                                    Text("Watched on \(watchedOn)")
                                        .font(.caption2).italic().foregroundColor(.black.opacity(0.6))
                                }
                                
                                if item.type == "tv" {
                                    let episodes = allItems.filter {
                                        $0.type == "episode" &&
                                        $0.parentTmdbId == item.tmdbId &&
                                        $0.status == "Ready"
                                    }
                                    let totalMins = episodes.compactMap { $0.runtime }.reduce(0, +)
                                    if totalMins > 0 {
                                        Text("Total Time Left: \(totalMins / 60)h \(totalMins % 60)m")
                                            .font(.caption).bold().foregroundColor(.blue)
                                    }
                                }
                            }
                            Spacer()
                            if item.type == "tv" {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.black)
                            }
                        }
                        .contentShape(Rectangle()) // Make the entire HStack tappable
                    }
                    .buttonStyle(.plain) // Make it look like regular content, not a button
                    
                    // Notification Flag Toggle
                    if item.type == "tv" {
                        Button(action: { onToggleNotifications(item) }) {
                            Image(systemName: item.isFlaggedForNotifications ? "bell.fill" : "bell")
                                .foregroundColor(item.isFlaggedForNotifications ? .accentYellow : .gray)
                        }
                        .buttonStyle(.plain)
                    }

                    // Action buttons - these should work independently
                    Button(action: { onEdit(item) }) {
                        Image(systemName: "pencil.circle").foregroundColor(.brandBlue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { onDelete(item) }) {
                        Image(systemName: "trash.circle").foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Text(item.status)
                            .font(.caption2)
                            .foregroundColor(item.status == "Watched" ? .darkGray : .blue)
                        
                        Toggle("", isOn: Binding(
                            get: { item.status == "Watched" },
                            set: { onStatusToggle(item, $0 ? "Watched" : "Ready") }
                        ))
                        .labelsHidden()
                        .scaleEffect(0.8)
                    }
                }
                
                if let providers = item.providers {
                    Text("Streaming on: \(providers)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let airDate = item.airDate {
                    Text("Air Date: \(airDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if isExpanded {
                let seasons = allItems.filter { $0.type == "season" && $0.parentTmdbId == item.tmdbId }
                    .sorted { $0.seasonNumber < $1.seasonNumber }
                
                ForEach(seasons) { season in
                    SeasonRow(
                        season: season,
                        allItems: allItems,
                        onStatusToggle: onStatusToggle,
                        onDelete: onDelete // Pass the closure directly
                    )
                        .padding(.leading, 16)
                }
            }
        }
        .padding(8)
        .background(rowBackgroundColor)
        .cornerRadius(8)
        .padding(.vertical, 1)
    }
    
    private var priorityLabel: String {
        switch item.priority {
        case 1: "Must Watch"
        case 2: "Soon"
        default: "Later"
        }
    }
    
    private var rowBackgroundColor: Color {
        if item.status == "Watched" { return Color.gray.opacity(0.3) }
        return .lightGreen
    }
}

struct SeasonRow: View {
    let season: WatchlistItem
    let allItems: [WatchlistItem]
    let onStatusToggle: (WatchlistItem, String) -> Void
    let onDelete: (WatchlistItem) -> Void // Changed to accept WatchlistItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center) {
                // Tappable area for expansion
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(season.title).font(.subheadline).bold().foregroundColor(.black)
                            
                            let episodes = allItems.filter {
                                $0.type == "episode" &&
                                $0.parentTmdbId == season.parentTmdbId &&
                                $0.seasonNumber == season.seasonNumber &&
                                $0.status == "Ready"
                            }
                            let totalMins = episodes.compactMap { $0.runtime }.reduce(0, +)
                            if totalMins > 0 {
                                Text("Time Left: \(totalMins / 60)h \(totalMins % 60)m")
                                    .font(.caption2).foregroundColor(.darkGray)
                            }
                            
                            if let airDate = season.airDate {
                                Text("Air Date: \(airDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2).foregroundColor(.black.opacity(0.7))
                            }
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.black)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Delete Button
                Button(action: { onDelete(season) }) {
                    Image(systemName: "trash").font(.caption).foregroundColor(.red)
                }
                .buttonStyle(.plain)

                // Status Toggle
                HStack(spacing: 4) {
                    Text(season.status)
                        .font(.caption2)
                        .foregroundColor(season.status == "Watched" ? .darkGray : .blue)
                    
                    Toggle("", isOn: Binding(
                        get: { season.status == "Watched" },
                        set: { onStatusToggle(season, $0 ? "Watched" : "Ready") }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.7)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.5))
            .cornerRadius(4)
            
            if isExpanded {
                let episodes = allItems.filter {
                    $0.type == "episode" &&
                    $0.parentTmdbId == season.parentTmdbId &&
                    $0.seasonNumber == season.seasonNumber
                }.sorted { $0.episodeNumber < $1.episodeNumber }
                
                ForEach(episodes) { episode in
                    EpisodeRow(
                        episode: episode,
                        onStatusToggle: onStatusToggle,
                        onDelete: onDelete // Pass the closure directly
                    )
                        .padding(.leading, 12)
                }
            }
        }
    }
}

struct EpisodeRow: View {
    let episode: WatchlistItem
    let onStatusToggle: (WatchlistItem, String) -> Void
    let onDelete: (WatchlistItem) -> Void // Changed to accept WatchlistItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Tappable area for expansion
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        let durationStr = episode.runtime != nil ? " (\(episode.runtime!)m)" : ""
                        Text("E\(episode.episodeNumber): \(episode.title)\(durationStr)")
                            .font(.caption).bold().foregroundColor(.black)
                        Spacer()
                        if episode.overview != nil {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.black)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Delete Button
                Button(action: { onDelete(episode) }) {
                    Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.red)
                }
                .buttonStyle(.plain)

                // Status Toggle
                HStack(spacing: 2) {
                    Text(episode.status)
                        .font(.system(size: 10))
                        .foregroundColor(episode.status == "Watched" ? .darkGray : .blue)
                    
                    Toggle("", isOn: Binding(
                        get: { episode.status == "Watched" },
                        set: { onStatusToggle(episode, $0 ? "Watched" : "Ready") }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.6)
                }
            }
            
            if isExpanded, let overview = episode.overview {
                Text(overview).font(.caption2).foregroundColor(.darkGray)
            }
            
            if let airDate = episode.airDate {
                Text("Air Date: \(airDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.black.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(4)
        .background(episode.status == "Watched" ? Color.gray.opacity(0.2) : Color.white.opacity(0.3))
        .cornerRadius(4)
    }
}

struct PriorityEditSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: WatchlistItem
    let onSave: (Int) -> Void
    @State private var selectedPriority: Int
    
    init(item: WatchlistItem, onSave: @escaping (Int) -> Void) {
        self.item = item
        self.onSave = onSave
        _selectedPriority = State(initialValue: item.priority)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Priority", selection: $selectedPriority) {
                    Text("1 - Must Watch Now").tag(1)
                    Text("2 - Watch Soon").tag(2)
                    Text("3 - Watch Later").tag(3)
                }
                .pickerStyle(.inline)
            }
            .navigationTitle("Edit Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedPriority)
                        dismiss()
                    }
                }
            }
        }
    }
}

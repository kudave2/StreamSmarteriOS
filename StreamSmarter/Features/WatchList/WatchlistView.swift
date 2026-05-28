import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WatchlistViewModel()
    @State private var itemToEdit: WatchlistItem?
    @State private var showDeleteConfirmation: WatchlistItem?
    
    @FocusState private var isSearchFocused: Bool
    @State private var selectedSeasonForEpisodes: WatchlistItem?
    @Namespace private var scrollSpace
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            Color.ssBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar (Search and Budget Alert)
                VStack(spacing: 0) {
                    if viewModel.selectedTab != .search {
                        HStack(alignment: .center, spacing: 12) {
                            Text("Watchlist")
                                .font(.title.bold())
                                .foregroundColor(.ssSecondary)
                            
                            Spacer()
                            
                            Button {
                                viewModel.showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(.ssSecondary)
                            }
                            
                            NavigationLink(value: "help") {
                                Image(systemName: "questionmark.circle")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }

                    HStack {
                        RetroSearchField(
                            searchQuery: $viewModel.searchQuery,
                            onActivate: {
                                viewModel.previousTab = viewModel.selectedTab
                                viewModel.selectedTab = .search
                            },
                            onBackClick: {
                                viewModel.selectedTab = viewModel.previousTab
                                viewModel.searchQuery = ""
                                isSearchFocused = false
                            },
                            isSearchActive: viewModel.selectedTab == .search,
                            isFocused: $isSearchFocused
                        )
                        .onChange(of: isSearchFocused) { _, isFocused in
                            // Switch to search tab as soon as the user taps the search bar
                            if isFocused && viewModel.selectedTab != .search {
                                viewModel.previousTab = viewModel.selectedTab
                                viewModel.selectedTab = .search
                            }
                        }
                        .onChange(of: viewModel.searchQuery) { _, newValue in
                            // Backup: switch to search tab if user somehow starts typing without triggering focus logic
                            if !newValue.isEmpty && viewModel.selectedTab != .search && isSearchFocused {
                                viewModel.previousTab = viewModel.selectedTab
                                viewModel.selectedTab = .search
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.ssBackground)
                    
                    // Budget Alert (from Android)
                    if let budgetAlert = viewModel.budgetAlert {
                        Button {
                            // TODO: Navigate to analysis?
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.white)
                                Text("LOW SIGNAL: \(budgetAlert.name) renews soon with zero activity. Suspend to save money?")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ssTertiary.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Main Content Area
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.selectedTab != .search {
                        Text("MONTHLY BUDGET: \(viewModel.activeTotalCost.formatted(.currency(code: "USD")))")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.ssPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        
                        // Channel Label
                        Text(channelLabel(for: viewModel.selectedTab))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.channelActive)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    // Wrap both the Search Results and the Watchlist in the SAME ScrollViewReader
                    // This ensures the proxy is ready the moment the Watchlist appears.
                    ScrollViewReader { proxy in
                        Group {
                            if viewModel.selectedTab == .search {
                                SearchResultsTab(results: viewModel.currentTabItems, searchQuery: viewModel.searchQuery) { item in
                                    isSearchFocused = false // Drop focus first
                                    // Give focus state a tiny moment to propagate before switching tabs
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        viewModel.handleSearchSelection(item: item)
                                    }
                                }
                            } else {
                                TabView(selection: $viewModel.selectedTab) {
                                    watchlistList(items: viewModel.availableReady).tag(WatchlistTab.available)
                                    watchlistList(items: viewModel.unavailableReady).tag(WatchlistTab.unavailable)
                                    watchlistList(items: viewModel.watchedItems).tag(WatchlistTab.watched)
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                            }
                        }
                        .onChange(of: viewModel.pendingScrollItemId) { _, id in
                            guard let scrollId = id else { return }
                            // Attempt scroll on next main loop pass to ensure List rows are instantiated
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 1.2)) {
                                    proxy.scrollTo(scrollId, anchor: .center)
                                }
                                viewModel.pendingScrollItemId = nil
                            }
                        }
                    }
                }
                
                // Bottom Tab Bar
                HStack(spacing: 20) {
                    channelButton(label: "01", subLabel: "AVAILABLE", tab: .available)
                    channelButton(label: "02", subLabel: "UNAVAILABLE", tab: .unavailable)
                    channelButton(label: "03", subLabel: "WATCHED", tab: .watched)
                }
                .padding(.bottom, 20)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color.ssSurface)
            }
        }
        .onChange(of: viewModel.selectedTab) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .animation(nil, value: viewModel.selectedTab)
        .environment(viewModel)
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        .toolbarBackground(Color(red: 253/255, green: 253/255, blue: 253/255), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .background(Color.ssBackground)
        .onAppear {
            viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $viewModel.showAddSheet, onDismiss: {
            viewModel.searchQuery = ""
        }) {
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
        .sheet(item: $selectedSeasonForEpisodes) { item in
            SeasonEpisodesSheet(season: item, allItems: viewModel.allItems, onStatusChange: viewModel.updateHierarchyStatus, onDelete: viewModel.deleteHierarchy, onRefreshSeason: viewModel.refreshSeasonEpisodes)
        }
    }
    
    @ViewBuilder
    private func watchlistList(items: [WatchlistItem]) -> some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items Found",
                    systemImage: "tv.slash",
                    description: Text("Try searching for something new or check another tab.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    watchlistRow(item, isHighlighted: viewModel.highlightedItemId == item.persistentModelID)
                        .id(item.persistentModelID)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.ssBackground)
        .scrollContentBackground(.hidden) // Hides the white system list background
    }

    @ViewBuilder
    private func watchlistRow(_ item: WatchlistItem, isHighlighted: Bool) -> some View {
        HierarchicalWatchlistRow(
            item: item,
            allItems: viewModel.allItems,
            onStatusToggle: { toggledItem, updatedStatus in
                viewModel.updateHierarchyStatus(toggledItem, newStatus: updatedStatus)
            },
            onEdit: { clickedItem in
                itemToEdit = clickedItem
            },
            onDelete: { itemToDelete in showDeleteConfirmation = itemToDelete },
            onToggleNotifications: { itemToFlag in viewModel.toggleNotificationFlag(for: itemToFlag) },
            onSeasonClick: { season in
                selectedSeasonForEpisodes = season
            },
            user: viewModel.user,
            activeServiceNames: viewModel.activeServiceNames,
            isHighlighted: isHighlighted
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }

    private func channelButton(label: String, subLabel: String, tab: WatchlistTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            if viewModel.selectedTab == .search || !viewModel.searchQuery.isEmpty {
                viewModel.searchQuery = ""
            }
            viewModel.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .channelActive : .gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.channelActive.opacity(0.15) : Color.black.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.channelActive : Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                Text(subLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? .channelActive : .gray)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private extension WatchlistView {
    func channelLabel(for tab: WatchlistTab) -> String {
        switch tab {
        case .available: return "CHANNEL 01: AVAILABLE"
        case .unavailable: return "CHANNEL 02: UNAVAILABLE"
        case .watched: return "CHANNEL 03: WATCHED"
        case .search: return "CHANNEL 04: SEARCH" // Should not be visible, but for completeness
        }
    }
}

struct RetroSearchField: View {
    @Binding var searchQuery: String
    let onActivate: () -> Void
    let onBackClick: () -> Void
    let isSearchActive: Bool
    
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            if isSearchActive {
                Button(action: onBackClick) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.gray)
                }
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search Watchlist...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(.ssText)
                    .focused($isFocused)
                    .overlay(
                        Text("Search Watchlist...")
                            .foregroundColor(.gray)
                            .opacity(searchQuery.isEmpty && !isFocused ? 1 : 0),
                        alignment: .leading
                    )
            }
            .onTapGesture {
                // Fixed: If not active, trigger activation logic instead of back click
                if !isSearchActive {
                    onActivate()
                    isFocused = true
                }
            }
            .padding(10)
            .background(Color.ssSurface)
            .cornerRadius(8)
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
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
    let onSeasonClick: (WatchlistItem) -> Void
    let user: User?
    let activeServiceNames: [String]
    let isHighlighted: Bool // New property
    
    @Environment(WatchlistViewModel.self) private var viewModel // Inject ViewModel from environment
    @State private var isExpanded = false
    @State private var currentHighlightAlpha: Double = 0.0 // For blinking effect
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Section: Title, Priority, Status Toggle
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline).bold().foregroundColor(.ssText)
                    priorityChip
                    watchedOnText
                    if item.type == "tv" { remainingTimeView }
                    if let providers = item.providers, !providers.isEmpty {
                        Text(providers.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                Spacer()
                statusTextAndToggle
            }
            .padding(.bottom, 10)
            
            Divider().background(Color.black.opacity(0.2)) // Android's HorizontalDivider
                .padding(.vertical, 4)
            
            HStack { // Bottom action row
                leftActionButtons
                Spacer()
                expandCollapseButton
            }
            
            if !matchingServices.isEmpty && item.status == "Ready" {
                watchOnButtons
            }
            if isExpanded {
                if item.type == "movie" {
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                            .padding(.horizontal, 4)
                    }
                } else {
                    let seasons = allItems.filter { $0.type == "season" && $0.parentTmdbId == item.tmdbId }
                        .sorted { $0.seasonNumber < $1.seasonNumber }
                    
                    ForEach(seasons) { season in // Android's SeasonSubCard
                        SeasonSubCard(
                            season: season,
                            allItems: allItems,
                            onStatusToggle: onStatusToggle,
                            onSeasonClick: onSeasonClick
                        )
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .padding(8)
        .background(backgroundCardColor)
        .overlay( // Android's border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.vertical, 1)
        .onTapGesture {
            isExpanded.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onAppear {
            if isHighlighted { startBlinking() }
        }
        .onChange(of: isHighlighted) { _, newVal in
            if newVal {
                startBlinking()
            } else {
                currentHighlightAlpha = 0.0
            }
        }
    }
    
    @ViewBuilder
    private var actionButtonsRow: some View {
        leftActionButtons
        Spacer()
        expandCollapseButton
    }
    
    private func startBlinking() {
        Task {
            for _ in 0..<5 { // Blink 5 times
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentHighlightAlpha = 1.0
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentHighlightAlpha = 0.0
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private var matchingServices: [String] {
        let providers = item.providers ?? ""
        var matches = [String]()
        
        if let mainService = user?.mainViewingService,
           viewModel.isServiceMatch(normalizedServiceName: viewModel.normalizeServiceName(mainService), providers: providers) {
            matches.append(mainService)
        }
        // Iterate through original service names, but use normalized versions for matching
        matches.append(contentsOf: viewModel.services.filter { $0.isActive && $0.name != user?.mainViewingService && viewModel.isServiceMatch(normalizedServiceName: viewModel.normalizeServiceName($0.name), providers: providers) }.map { $0.name })
        
        return Array(Set(matches)) // Use Set to ensure uniqueness
    }
    
    private func isServiceMatch(serviceName: String, providers: String, pattern: String) -> Bool {
        let pRaw = providers.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        let sRaw = serviceName.lowercased().replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        if sRaw.count > 2 && pRaw.contains(sRaw) { return true }
        if pRaw.count > 2 && sRaw.contains(pRaw) { return true }
        if sRaw == "appletv" && pRaw.contains("appletv") { return true }
        if sRaw.contains("disney") && (pRaw.contains("hulu") || pRaw.contains("espn")) { return true }
        return false
    }
    
    private var priorityChip: some View {
        Text(priorityLabel.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(item.priority == 1 ? .ssTertiary : .ssPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.3))
            .cornerRadius(2)
    }
    
    @ViewBuilder
    private var statusTextAndToggle: some View {
        HStack(spacing: 4) {
            Text(item.status == "Watched" ? "WATCHED" : "READY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(item.status == "Watched" ? .gray : .channelActive)
            
            Toggle("", isOn: Binding(
                get: { item.status == "Watched" },
                set: { newValue in
                    onStatusToggle(item, newValue ? "Watched" : "Ready")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            ))
            .toggleStyle(RetroToggleStyle())
        }
    }
    
    @ViewBuilder
    private var watchedOnText: some View {
        if item.status == "Watched", let watchedOn = item.watchedOn {
            Text("Watched on \(watchedOn)").font(.caption2).italic()
                .foregroundColor(.ssText.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var remainingTimeView: some View {
        let totalMins = allItems.filter { $0.parentTmdbId == item.tmdbId && $0.type == "episode" && $0.status == "Ready" }.reduce(0) { $0 + ($1.runtime ?? 0) }
        if totalMins > 0 {
            Text("TOTAL REMAINING: \(totalMins / 60)H \(totalMins % 60)M")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.ssSecondary)
        }
    }
    
    @ViewBuilder
    private var leftActionButtons: some View {
        // Notification Toggle
        if item.type == "tv" || item.type == "movie" { // Android allows notifications for movies too
            Button(action: { onToggleNotifications(item) }) {
                Image(systemName: item.isFlaggedForNotifications ? "bell.fill" : "bell")
                    .foregroundColor(item.isFlaggedForNotifications ? .ssSecondary : .gray)
            }
            .buttonStyle(.plain)
        }

        // Edit Button
        Button(action: { onEdit(item) }) {
            Image(systemName: "pencil.circle").foregroundColor(.gray)
        }
        .buttonStyle(.plain)
        
        // Delete Button
        Button(action: { onDelete(item) }) {
            Image(systemName: "trash.circle").foregroundColor(.curtainRed.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var expandCollapseButton: some View {
        if item.type == "tv" || item.type == "movie" { // Only show if it has children or details
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "CLOSE" : (item.type == "movie" ? "DETAILS" : "SEASONS"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.ssText)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.ssText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.2))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var watchOnButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(matchingServices, id: \.self) { serviceName in
                    WatchOnButton(serviceName: serviceName, itemTitle: item.title)
                }
            }
            .padding(.vertical, 8)
        }
    }
    private var backgroundCardColor: some View {
        let baseColor: Color
        if item.status == "Watched" {
            baseColor = .ssMutedWatched
        } else if let providers = item.providers, !providers.isEmpty {
            baseColor = .ssMutedAvailable
        } else {
            baseColor = .ssMutedUnavailable
        }
        return baseColor.overlay(Color.yellow.opacity(currentHighlightAlpha * 0.3))
    }

    private var priorityLabel: String {
        switch item.priority {
        case 1: "Must Watch"
        case 2: "Watch Soon"
        default: "Later"
        }
    }
}

struct WatchOnButton: View {
    @Environment(WatchlistViewModel.self) private var viewModel
    let serviceName: String
    let itemTitle: String
    
    var body: some View {
        Button {
            viewModel.launchStreamingApp(serviceName: serviceName, title: itemTitle)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("WATCH ON \(serviceName.uppercased())")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.channelActive)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.channelActive.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.channelActive, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PriorityEditSheet: View { // Moved from WatchlistView.swift
    @Environment(\.dismiss) var dismiss
    let item: WatchlistItem
    let onSave: (Int) -> Void
    @State private var selectedPriority: Int
    @AppStorage("isDarkMode") private var isDarkMode = true
    
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
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

struct SeasonSubCard: View { // Moved from WatchlistView.swift
    let season: WatchlistItem
    let allItems: [WatchlistItem]
    let onStatusToggle: (WatchlistItem, String) -> Void
    let onSeasonClick: (WatchlistItem) -> Void
    var body: some View {
        Button {
            onSeasonClick(season)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(season.title).font(.subheadline.bold()).foregroundColor(.ssText)
                    Text("TAP TO VIEW EPISODES").font(.system(size: 10, design: .monospaced)).foregroundColor(.ssText.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(season.status == "Watched" ? "WATCHED" : "READY").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(season.status == "Watched" ? .gray : .channelActive)
                    Toggle("", isOn: Binding(
                        get: { season.status == "Watched" },
                        set: { newValue in
                            onStatusToggle(season, newValue ? "Watched" : "Ready")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    ))
                    .toggleStyle(RetroToggleStyle())
                }
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5))
            }
            .padding(8).background(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1)).cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

struct EpisodeSubCard: View { // Moved from WatchlistView.swift
    let episode: WatchlistItem
    let onStatusToggle: (WatchlistItem, String) -> Void
    let onDelete: (WatchlistItem) -> Void
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { isExpanded.toggle(); UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                    HStack {
                        Text("E\(episode.episodeNumber): \(episode.title)\(episode.runtime != nil ? " (\(episode.runtime!)m)" : "")").font(.caption).bold().foregroundColor(.ssText)
                        Spacer()
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                HStack(spacing: 2) {
                    Text(episode.status == "Watched" ? "WATCHED" : "READY").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(episode.status == "Watched" ? .gray : .channelActive)
                    Toggle("", isOn: Binding(
                        get: { episode.status == "Watched" },
                        set: { newValue in
                            onStatusToggle(episode, newValue ? "Watched" : "Ready")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    ))
                    .toggleStyle(RetroToggleStyle())
                }
                Button(action: { onDelete(episode) }) { 
                    Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.curtainRed.opacity(0.6)) 
                }.buttonStyle(.plain)
            }
            if isExpanded, let overview = episode.overview { Text(overview).font(.caption2).foregroundColor(.gray).padding(.top, 4) }
        }
        .padding(8).background(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.15), lineWidth: 1)).cornerRadius(4)
    }
}

struct SeasonEpisodesSheet: View { // Moved from WatchlistView.swift
    @Environment(\.dismiss) var dismiss
    let season: WatchlistItem
    let allItems: [WatchlistItem]
    let onStatusChange: (WatchlistItem, String) -> Void
    let onDelete: (WatchlistItem) -> Void
    let onRefreshSeason: (WatchlistItem) async -> Void
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        let episodes = allItems.filter { $0.type == "episode" && $0.parentTmdbId == season.parentTmdbId && $0.seasonNumber == season.seasonNumber }.sorted { $0.episodeNumber < $1.episodeNumber }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(season.title.uppercased()).font(.headline.bold()).foregroundColor(.ssPrimary)
                    Text("EPISODE MANIFEST").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                Button { onDelete(season); dismiss() } label: { Image(systemName: "trash").foregroundColor(.curtainRed) }
            }.padding(.bottom, 12)
            Divider().background(Color.gray.opacity(0.4)).padding(.bottom, 12)
            ScrollView { VStack(spacing: 8) { ForEach(episodes) { ep in EpisodeSubCard(episode: ep, onStatusToggle: onStatusChange, onDelete: onDelete) } } }
            Button { dismiss() } label: { 
                Text("CLOSE").font(.system(.body, design: .monospaced)).foregroundColor(.ssText).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.ssSurface).cornerRadius(4) 
            }.padding(.top, 16)
        }
        .padding()
        .background(Color.ssBackground.ignoresSafeArea())
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .task { 
            if episodes.contains(where: { $0.overview == nil || $0.runtime == nil }) { 
                await onRefreshSeason(season) 
            } 
        }
    }
}

struct RetroNoSignalGraphic: View { // Moved from WatchlistView.swift
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.largeTitle).foregroundColor(.gray)
            Text(message).font(.system(.body, design: .monospaced)).foregroundColor(.gray).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }
}

struct RetroToggleStyle: ToggleStyle { // Moved from WatchlistView.swift
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.gray.opacity(0.3) : Color.channelActive.opacity(0.3))
                    .frame(width: 28, height: 14)
                
                Circle()
                    .fill(configuration.isOn ? Color.gray : Color.channelActive)
                    .frame(width: 12, height: 12)
                    .padding(.horizontal, 1)
            }
        }
        .buttonStyle(.plain)
    }
}

extension Array { // Moved from WatchlistView.swift (and made conditional)
    func sortedBy<Value: Comparable>(_ keyPath: KeyPath<Element, Value>) -> [Element] {
        self.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }
}

struct SearchResultsTab: View { // Moved from WatchlistView.swift
    let results: [WatchlistItem]
    let searchQuery: String
    let onItemClick: (WatchlistItem) -> Void
    
    var body: some View {
        if results.isEmpty { RetroNoSignalGraphic(message: searchQuery.isEmpty ? "IDLE: START TYPING" : "SEARCH ERROR: NO MATCHES") }
        else {
            List {
                ForEach(results) { item in
                    Button { onItemClick(item) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                highlightedText(text: item.title, query: searchQuery)
                                    .font(.headline)
                                    .foregroundColor(.ssText)
                                Text("\(item.type.uppercased()) • \(item.status)").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }.padding(12).background(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1)).cornerRadius(8)
                    }.buttonStyle(.plain).listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }.listStyle(.plain).background(Color.ssBackground)
        }
    }
    
    private func highlightedText(text: String, query: String) -> Text {
        guard !query.isEmpty else { return Text(text) }
        var attributedString = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        
        if let range = lowerText.range(of: lowerQuery) {
            let start = AttributedString.Index(range.lowerBound, within: attributedString)
            let end = AttributedString.Index(range.upperBound, within: attributedString)
            if let start = start, let end = end {
                attributedString[start..<end].backgroundColor = .ssPrimary.opacity(0.6)
            }
        }
        return Text(attributedString)
    }
}

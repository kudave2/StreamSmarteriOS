import SwiftUI
import SwiftData

// Conform TMDB search results to Identifiable to support SwiftUI sheets and lists
extension TmdbSearchResult: Identifiable {}
extension TmdbSeason: Identifiable {}
extension TmdbEpisode: Identifiable {}

struct AddWatchlistView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WatchlistViewModel
    @FocusState private var isFocused: Bool // Add FocusState here
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.retroTVDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Input Area
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search Movies & TV Shows...", text: $viewModel.searchQuery)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .focused($isFocused)
                            .overlay(
                                Text("Search Movies & TV Shows...")
                                    .foregroundColor(.gray)
                                    .opacity(viewModel.searchQuery.isEmpty && !isFocused ? 1 : 0),
                                alignment: .leading
                            )
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.searchQuery) { _, newValue in
                                Task { await viewModel.searchTmdb(newValue) }
                            }
                        
                        if viewModel.isSearching {
                            ProgressView().tint(.accentYellow)
                        } else if !viewModel.searchQuery.isEmpty {
                            Button { viewModel.searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.retroTVGray)
                    .cornerRadius(10)
                    .padding()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if viewModel.searchQuery.isEmpty {
                                // 1. Trending Discovery Section
                                if !viewModel.trendingResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Trending Today")
                                            .font(.title3.bold())
                                            .foregroundColor(.accentYellow)
                                            .padding(.horizontal)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(viewModel.trendingResults, id: \.id) { result in
                                                    TmdbResultCard(result: result, viewModel: viewModel)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                // 2. Popular Section
                                if !viewModel.popularResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Popular Now")
                                            .font(.title3.bold())
                                            .foregroundColor(.accentYellow)
                                            .padding(.horizontal)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(viewModel.popularResults, id: \.id) { result in
                                                    TmdbResultCard(result: result, viewModel: viewModel)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                
                                // 3. Recommendations Section
                                if !viewModel.recommendations.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Recommended for You")
                                            .font(.title3.bold())
                                            .foregroundColor(.accentYellow)
                                            .padding(.horizontal)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(viewModel.recommendations, id: \.id) { result in
                                                    TmdbResultCard(result: result, viewModel: viewModel)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }

                                if viewModel.isSearching && viewModel.trendingResults.isEmpty {
                                    ProgressView("Finding suggestions...")
                                        .tint(.accentYellow)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 40)
                                }
                                
                                if !viewModel.isSearching && viewModel.trendingResults.isEmpty && viewModel.popularResults.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "Popcorn.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.retroGray)
                                        Text("No recommendations found.\nCheck your API key in Profile.")
                                            .multilineTextAlignment(.center)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                                }
                            } else {
                                // Search Results List
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.searchResults, id: \.id) { result in
                                        TmdbResultRow(result: result, viewModel: viewModel)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StreamSmarterLogoView(
                        iconSize: 24,
                        fontSize: 24,
                        taglineSize: 8
                    )
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.brandBlue)
                }
            }
            .sheet(item: $viewModel.selectedResult) { result in
                SelectionDetailSheet(result: result, viewModel: viewModel) {
                    viewModel.selectedResult = nil
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchTrendingContent()
                }
            }
            .contentShape(Rectangle())
            .alert("API Key Error", isPresented: $viewModel.showApiKeyError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We couldn't reach TMDB. Please verify your API key in the Profile tab.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TmdbResultCard: View {
    let result: TmdbSearchResult
    let viewModel: WatchlistViewModel
    @State private var seasons: Int? = nil

    private var displayTitle: String {
        let t = result.title ?? ""
        let n = result.name ?? ""
        if !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
        if !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "Unknown Content"
    }
    private var posterUrl: URL? {
        guard let path = result.posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.selectedResult = result // Triggers the detail sheet
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: posterUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.retroGray.overlay(Image(systemName: "tv").foregroundColor(.gray))
                        }
                        .frame(width: 140, height: 210)
                        .cornerRadius(8)
                        .clipped()
                        
                        if viewModel.isItemInWatchlist(tmdbId: result.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.black))
                                .padding(8)
                        }
                    }
                    
                    Text(displayTitle)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(width: 140, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .frame(width: 140, height: 32, alignment: .topLeading)
                    
                    HStack(spacing: 4) {
                        Text(String((result.releaseDate ?? result.firstAirDate ?? "----").prefix(4)))
                        if let s = seasons {
                            Text("• \(s) Seasons")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
        .onAppear {
            let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
            if mediaType == "tv" {
                Task {
                    let details = await viewModel.getTvDetails(id: result.id)
                    seasons = details?.numberOfSeasons
                }
            }
        }
    }
}

struct TmdbResultRow: View {
    let result: TmdbSearchResult
    let viewModel: WatchlistViewModel
    @State private var seasons: Int? = nil
    
    var body: some View {
        Button {
            viewModel.selectedResult = result
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w92\(result.posterPath ?? "")")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.retroGray.overlay(Image(systemName: "tv").foregroundColor(.gray))
                }
                .frame(width: 60, height: 90)
                .cornerRadius(4)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title ?? result.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
                    HStack {
                        Text(String((result.releaseDate ?? result.firstAirDate ?? "----").prefix(4)))
                        if let s = seasons {
                            Text("• \(s) Seasons")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    
                    Text(mediaType == "tv" ? "TV Show" : "Movie")
                        .font(.caption2)
                        .foregroundColor(.brandBlue)
                }
                
                Spacer()
                
                Image(systemName: viewModel.isItemInWatchlist(tmdbId: result.id) ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(viewModel.isItemInWatchlist(tmdbId: result.id) ? .green : .brandBlue)
                    .font(.title2)
            }
            .padding(8)
            .background(Color.retroGray.opacity(0.5))
            .cornerRadius(8)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .onAppear {
            let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
            if mediaType == "tv" {
                Task {
                    let details = await viewModel.getTvDetails(id: result.id)
                    seasons = details?.numberOfSeasons
                }
            }
        }
    }
}

/// This sheet mimics the Android AddWatchlistItemDialog functionality
struct SelectionDetailSheet: View {
    let result: TmdbSearchResult
    let viewModel: WatchlistViewModel
    let onComplete: () -> Void
    
    @State private var selectedPriority: Int = 2
    @State private var selectedAllSeries: Bool = false
    @State private var tvDetails: TmdbTvDetails?
    @State private var seasonDetails: [Int: TmdbSeason] = [:] // Map season number to its details
    @State private var selectedSeasonsAndEpisodes: [Int: Set<Int>] = [:] // Season -> Set of Episode numbers
    @State private var isLoading = true
    @State private var isAdding = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(.accentYellow)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            Divider().background(Color.white.opacity(0.2))
                            prioritySection
                            tvSelectionSection
                            Spacer(minLength: 40)
                            addButton
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Configure Addition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { onComplete() }.foregroundColor(.accentYellow)
                }
            }
        }
        .onAppear {
            Task {
                let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
                if mediaType == "tv" {
                    let fetchedDetails = await viewModel.getTvDetails(id: result.id)
                    self.tvDetails = fetchedDetails
                    
                    // Pre-fetch season details for all seasons to enable "Add Entire Series"
                    if let seasons = fetchedDetails?.seasons {
                        await withTaskGroup(of: (Int, TmdbSeason?).self) { group in
                            for season in seasons {
                                let sn = season.seasonNumber
                                group.addTask {
                                    let sDetails = await viewModel.getTvSeasonDetails(tvId: result.id, seasonNumber: sn)
                                    return (sn, sDetails)
                                }
                            }
                            for await (sn, sDetails) in group {
                                if let sDetails = sDetails {
                                    self.seasonDetails[sn] = sDetails
                                    // Reactive selection: if 'Add All' was pressed during load, 
                                    // fill this season's episodes as they arrive.
                                    if selectedAllSeries {
                                        let eps = sDetails.episodes?.map { $0.episodeNumber } ?? []
                                        selectedSeasonsAndEpisodes[sn] = Set(eps)
                                    }
                                }
                            }
                        }
                    }
                }
                isLoading = false
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w154\(result.posterPath ?? "")")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: { Color.retroGray }
            .frame(width: 100)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(result.title ?? result.name ?? "Unknown")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
                Text(mediaType.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandBlue)
                    .cornerRadius(4)
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WATCH PRIORITY").font(.caption.bold()).foregroundColor(.popcornYellow)
            Picker("Priority", selection: $selectedPriority) {
                Text("Must Watch Now").tag(1)
                Text("Watch Soon").tag(2)
                Text("Watch Later").tag(3)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var tvSelectionSection: some View {
        let mediaType = result.mediaType ?? (result.name != nil ? "tv" : "movie")
        if mediaType == "tv", let details = tvDetails {
            VStack(alignment: .leading, spacing: 15) {
                Text("ADD CONTENT").font(.caption.bold()).foregroundColor(.popcornYellow)
                
                Toggle(isOn: Binding(
                    get: { selectedAllSeries },
                    set: { newValue in
                        selectedAllSeries = newValue
                        toggleAllSeries(details: details, newValue: newValue)
                    }
                )) {
                    Text("Add Entire Series").font(.headline).foregroundColor(.white)
                }
                .tint(.accentYellow)
                
                Divider().background(Color.white.opacity(0.2))
                
                ForEach(details.seasons ?? []) { season in
                    let seasonNumber = season.seasonNumber
                    if seasonNumber > 0 {
                        VStack(alignment: .leading) {
                            DisclosureGroup {
                                if let episodes = seasonDetails[seasonNumber]?.episodes {
                                ForEach(episodes) { episode in
                                    let episodeNumber = episode.episodeNumber
                                    episodeToggle(seasonNumber: seasonNumber, episodeNumber: episodeNumber, episodeName: episode.name)
                                        .padding(.leading, 32) // Precise indent
                                    }
                                } else {
                                    Text("Loading episodes...").font(.caption).foregroundColor(.gray)
                                }
                            } label: {
                                seasonToggle(seasonNumber: seasonNumber, seasonName: season.name)
                            }
                            .onChange(of: selectedSeasonsAndEpisodes[seasonNumber]?.count) { _, _ in
                                updateSelectedAllSeriesState(details: details)
                            }
                            .onAppear {
                                Task {
                                    if seasonDetails[seasonNumber] == nil {
                                        seasonDetails[seasonNumber] = await viewModel.getTvSeasonDetails(tvId: result.id, seasonNumber: seasonNumber)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    private func seasonToggle(seasonNumber: Int, seasonName: String?) -> some View {
        let seasonEps = seasonDetails[seasonNumber]?.episodes ?? []
        let selectedEps = selectedSeasonsAndEpisodes[seasonNumber] ?? []
        let isSelected = !seasonEps.isEmpty && selectedEps.count == seasonEps.count
        
        return HStack(spacing: 12) {
            Button {
                let nextValue = !isSelected
                if nextValue {
                    let eps = seasonDetails[seasonNumber]?.episodes?.map { $0.episodeNumber } ?? []
                    selectedSeasonsAndEpisodes[seasonNumber] = Set(eps)
                } else {
                    selectedSeasonsAndEpisodes.removeValue(forKey: seasonNumber)
                }
                selectedAllSeries = false
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentYellow : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Text("Season \(seasonNumber): \(seasonName ?? "Unknown Season")")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
    }

    private func episodeToggle(seasonNumber: Int, episodeNumber: Int, episodeName: String?) -> some View {
        let isSelected = selectedSeasonsAndEpisodes[seasonNumber]?.contains(episodeNumber) ?? false
        
        return HStack(spacing: 12) {
            Button {
                if !isSelected {
                    selectedSeasonsAndEpisodes[seasonNumber, default: []].insert(episodeNumber)
                } else {
                    selectedSeasonsAndEpisodes[seasonNumber]?.remove(episodeNumber)
                    if selectedSeasonsAndEpisodes[seasonNumber]?.isEmpty ?? false {
                        selectedSeasonsAndEpisodes.removeValue(forKey: seasonNumber)
                    }
                }
                selectedAllSeries = false
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .brandBlue : .gray)
                    .padding(.trailing, 12)
            }
            .buttonStyle(.plain)

            Text("E\(episodeNumber): \(episodeName ?? "Unknown Episode")")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }

    private var addButton: some View {
        Button {
            Task {
                isAdding = true
                await performAddition()
                isAdding = false
                onComplete()
            }
        } label: {
            HStack {
                if isAdding { ProgressView().tint(.black) }
                Text(isAdding ? "Adding..." : "Add to Watchlist").font(.headline.bold())
            }
            .frame(maxWidth: .infinity).padding().background(Color.accentYellow).foregroundColor(.black).cornerRadius(12)
        }
        .disabled(isAdding)
    }

    private func performAddition() async {
        let type = result.mediaType ?? (result.name != nil ? "tv" : "movie")
        var selectionsToAdd: [WatchlistSelection] = []
        if type == "movie" {
            selectionsToAdd.append(WatchlistSelection(tmdbResult: result, itemType: type, seasonNumber: nil, episodeNumber: nil))
        } else if type == "tv" {
            for (seasonNum, episodeNums) in selectedSeasonsAndEpisodes {
                for episodeNum in episodeNums {
                    selectionsToAdd.append(WatchlistSelection(tmdbResult: result, itemType: "episode", seasonNumber: seasonNum, episodeNumber: episodeNum))
                }
            }
        }
        await viewModel.addItemsToWatchlist(selections: selectionsToAdd, priority: selectedPriority)
    }

    private func toggleAllSeries(details: TmdbTvDetails, newValue: Bool) {
        if newValue {
            selectedSeasonsAndEpisodes.removeAll()
            for season in details.seasons ?? [] {
                let seasonNumber = season.seasonNumber
                if seasonNumber > 0 {
                    let eps = seasonDetails[seasonNumber]?.episodes?.map { $0.episodeNumber } ?? []
                    selectedSeasonsAndEpisodes[seasonNumber] = Set(eps)
                }
            }
        } else {
            selectedSeasonsAndEpisodes.removeAll()
        }
    }

    private func updateSelectedAllSeriesState(details: TmdbTvDetails) {
        let relevantSeasons = details.seasons?.filter { $0.seasonNumber > 0 } ?? []
        let seasonNums = relevantSeasons.compactMap { $0.seasonNumber }
        
        let totalEpisodesCount = seasonNums.reduce(0) { count, sn in
            count + (seasonDetails[sn]?.episodes?.count ?? 0)
        }
        
        let selectedEpisodesCount = selectedSeasonsAndEpisodes.values.reduce(0) { sum, set in
            sum + set.count
        }
        
        selectedAllSeries = (totalEpisodesCount > 0 && selectedEpisodesCount == totalEpisodesCount)
    }
}
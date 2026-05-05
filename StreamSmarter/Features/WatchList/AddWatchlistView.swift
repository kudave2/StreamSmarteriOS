import SwiftUI
import SwiftData

enum AddWatchlistStep {
    case search, tvDetailSelection, prioritySelection
}

struct WatchlistSelection: Identifiable, Equatable {
    let id = UUID() // For ForEach
    let tmdbResult: TmdbSearchResult
    let itemType: String // "movie", "tv", "season", "episode"
    var seasonNumber: Int?
    var episodeNumber: Int?
    
    // Equatable conformance for easier checking
    static func == (lhs: WatchlistSelection, rhs: WatchlistSelection) -> Bool {
        lhs.tmdbResult.id == rhs.tmdbResult.id &&
        lhs.itemType == rhs.itemType &&
        lhs.seasonNumber == rhs.seasonNumber &&
        lhs.episodeNumber == rhs.episodeNumber
    }
}

struct AddWatchlistView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WatchlistViewModel // Use @Bindable for @Observable classes
    @FocusState private var isSearchFieldFocused: Bool
    
    @State private var searchQuery: String = ""
    @State private var currentStep: AddWatchlistStep = .search
    @State private var selectedResults: [WatchlistSelection] = []
    @State private var selectedPriority: Int = 1 // Default to "Must Watch Now"
    
    // For TV detail selection
    @State private var detailShow: TmdbSearchResult? = nil
    @State private var tvDetails: TmdbTvDetails? = nil
    @State private var selectedSeasonDetails: TmdbSeason? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(navigationTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                
                switch currentStep {
                case .search:
                    searchStepView
                case .tvDetailSelection:
                    tvDetailSelectionStepView
                case .prioritySelection:
                    prioritySelectionStepView
                }
                
                Spacer()
            }
            .padding()
            .background(Color.retroGray.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                isSearchFieldFocused = true
            }
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .search: return "TMDB Search"
        case .tvDetailSelection: return "Select Details for \(detailShow?.name ?? detailShow?.title ?? "TV Show")"
        case .prioritySelection: return "Set Priority"
        }
    }
    
    // MARK: - Step 1: Search
    private var searchStepView: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Search Title or Actor", text: $searchQuery)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        Task { await viewModel.searchTmdb(searchQuery) }
                    }
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                
                if viewModel.isSearching {
                    ProgressView().tint(.accentYellow)
                } else {
                    Button {
                        Task { await viewModel.searchTmdb(searchQuery) }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.accentYellow)
                    }
                }
            }
            
            if !viewModel.searchResults.isEmpty {
                List {
                    ForEach(viewModel.searchResults, id: \.id) { result in
                        let isSelected = selectedResults.contains(where: { $0.tmdbResult.id == result.id && $0.itemType == "movie" })
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(result.title ?? result.name ?? "Unknown") (\(result.displayDate))")
                                    .foregroundColor(isSelected ? .solidGreen : .black)
                                    .fontWeight(isSelected ? .bold : .regular)
                                Text(result.mediaType?.uppercased() ?? "UNKNOWN")
                                    .font(.caption)
                                    .foregroundColor(.darkGray)
                            }
                            Spacer()
                            if result.mediaType == "movie" {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .solidGreen : .darkGray)
                            } else {
                                Image(systemName: "chevron.forward")
                                    .font(.body.bold())
                                    .foregroundColor(.brandBlue)
                            }
                        }
                        .padding(10)
                        .background(Color(white: 0.85)) // Matches Android Color.LightGray
                        .cornerRadius(8)
                        .onTapGesture {
                            if result.mediaType == "movie" {
                                if isSelected {
                                    selectedResults.removeAll(where: { $0.tmdbResult.id == result.id && $0.itemType == "movie" })
                                } else {
                                    selectedResults.append(WatchlistSelection(tmdbResult: result, itemType: "movie"))
                                }
                            } else if result.mediaType == "tv" {
                                detailShow = result
                                Task {
                                    tvDetails = await viewModel.getTvDetails(id: result.id)
                                    currentStep = .tvDetailSelection
                                }
                            }
                        }
                    }
                }
                .listStyle(.grouped) // Better separation for dark mode lists
                .background(Color.retroGray)
                
                Button("Continue (\(selectedResults.count) items)") {
                    currentStep = .prioritySelection
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    
    // MARK: - Step 2: TV Detail Selection
    private var tvDetailSelectionStepView: some View {
        VStack(spacing: 16) {
            if let show = detailShow {
                Text("Adding from: \(show.name ?? show.title ?? "TV Show")")
                    .font(.subheadline)
                    .foregroundColor(.accentYellow)
                
                List {
                    // Option to track entire show
                    let isShowSelected = selectedResults.contains(where: { $0.tmdbResult.id == show.id && $0.itemType == "tv" })
                    HStack {
                        Text("Track Entire Show")
                            .foregroundColor(isShowSelected ? .solidGreen : .black)
                            .fontWeight(isShowSelected ? .bold : .regular)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isShowSelected },
                            set: { newValue in
                                if newValue {
                                    // Select show and all its seasons/episodes
                                    selectedResults.removeAll(where: { $0.tmdbResult.id == show.id })
                                    selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "tv"))
                                    Task {
                                        for season in tvDetails?.seasons ?? [] {
                                            selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "season", seasonNumber: season.seasonNumber))
                                            if let sDetails = await viewModel.getTvSeasonDetails(tvId: show.id, seasonNumber: season.seasonNumber) {
                                                for episode in sDetails.episodes ?? [] {
                                                    selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "episode", seasonNumber: season.seasonNumber, episodeNumber: episode.episodeNumber))
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // Unselect show and all its seasons/episodes
                                    selectedResults.removeAll(where: { $0.tmdbResult.id == show.id })
                                }
                            }
                        ))
                        .toggleStyle(CheckboxToggleStyle())
                    }
                    .listRowBackground(Color(white: 0.85))
                    .listRowSeparator(.hidden)
                    
                    // Seasons list
                    if selectedSeasonDetails == nil {
                        ForEach(tvDetails?.seasons ?? [], id: \.id) { season in
                            let isSeasonSelected = selectedResults.contains(where: { $0.tmdbResult.id == show.id && $0.itemType == "season" && $0.seasonNumber == season.seasonNumber })
                            let selectedEpsCount = selectedResults.filter({ $0.tmdbResult.id == show.id && $0.itemType == "episode" && $0.seasonNumber == season.seasonNumber }).count
                            
                            VStack(alignment: .leading) {
                                HStack(spacing: 0) {
                                    // Expansion Target: Metadata Area + Spacer + Chevron
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(season.name ?? "Season \(season.seasonNumber)")")
                                                .foregroundColor(isSeasonSelected ? .solidGreen : .black)
                                                .fontWeight(isSeasonSelected ? .bold : .regular)
                                            
                                            if selectedEpsCount > 0 && !isSeasonSelected {
                                                Text("(\(selectedEpsCount) Episodes Selected)")
                                                    .font(.caption2)
                                                    .foregroundColor(.darkGray)
                                            }
                                            
                                            Text("Season \(season.seasonNumber) • \(season.episodeCount ?? 0) Episodes • \(season.airDate?.prefix(4) ?? "N/A")")
                                                .font(.caption)
                                                .foregroundColor(.darkGray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.forward")
                                            .font(.body.bold())
                                            .foregroundColor(.brandBlue)
                                            .padding(.trailing, 12)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Task {
                                            selectedSeasonDetails = await viewModel.getTvSeasonDetails(tvId: show.id, seasonNumber: season.seasonNumber)
                                        }
                                    }
                                    
                                    // Selection Target: Checkbox
                                    Toggle("", isOn: Binding(
                                        get: { isSeasonSelected },
                                        set: { newValue in
                                            if newValue {
                                                selectedResults.removeAll(where: { $0.tmdbResult.id == show.id && $0.seasonNumber == season.seasonNumber })
                                                selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "season", seasonNumber: season.seasonNumber))
                                                Task {
                                                    if let sDetails = await viewModel.getTvSeasonDetails(tvId: show.id, seasonNumber: season.seasonNumber) {
                                                        for episode in sDetails.episodes ?? [] {
                                                            selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "episode", seasonNumber: season.seasonNumber, episodeNumber: episode.episodeNumber))
                                                        }
                                                    }
                                                }
                                            } else {
                                                selectedResults.removeAll(where: { $0.tmdbResult.id == show.id && $0.seasonNumber == season.seasonNumber })
                                            }
                                        }
                                    ))
                                    .toggleStyle(CheckboxToggleStyle())
                                }
                            }
                            .listRowBackground(Color(white: 0.85))
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        // Episodes list for selected season
                        Text("Season: \(selectedSeasonDetails?.name ?? "Unknown")")
                            .font(.subheadline.bold())
                            .foregroundColor(.solidGreen)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        
                        ForEach(selectedSeasonDetails?.episodes ?? [], id: \.id) { episode in
                            let isEpisodeSelected = selectedResults.contains(where: { $0.tmdbResult.id == show.id && $0.itemType == "episode" && $0.seasonNumber == selectedSeasonDetails?.seasonNumber && $0.episodeNumber == episode.episodeNumber })
                            
                            HStack {
                                Text("E\(episode.episodeNumber): \(episode.name ?? "Unknown")")
                                    .foregroundColor(isEpisodeSelected ? .solidGreen : .black)
                                    .fontWeight(isEpisodeSelected ? .bold : .regular)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { isEpisodeSelected },
                                    set: { newValue in
                                        if newValue {
                                            selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "episode", seasonNumber: selectedSeasonDetails?.seasonNumber, episodeNumber: episode.episodeNumber))
                                            // If all episodes in season selected, select season
                                            let totalEpisodesInSeason = selectedSeasonDetails?.episodes?.count ?? 0
                                            let currentlySelectedEpisodes = selectedResults.filter({ $0.tmdbResult.id == show.id && $0.itemType == "episode" && $0.seasonNumber == selectedSeasonDetails?.seasonNumber }).count
                                            if currentlySelectedEpisodes == totalEpisodesInSeason {
                                                if !selectedResults.contains(where: { $0.tmdbResult.id == show.id && $0.itemType == "season" && $0.seasonNumber == selectedSeasonDetails?.seasonNumber }) {
                                                    selectedResults.append(WatchlistSelection(tmdbResult: show, itemType: "season", seasonNumber: selectedSeasonDetails?.seasonNumber))
                                                }
                                            }
                                        } else {
                                            selectedResults.removeAll(where: { $0.tmdbResult.id == show.id && $0.itemType == "episode" && $0.seasonNumber == selectedSeasonDetails?.seasonNumber && $0.episodeNumber == episode.episodeNumber })
                                            // If any episode unselected, unselect parent season
                                            selectedResults.removeAll(where: { $0.tmdbResult.id == show.id && $0.itemType == "season" && $0.seasonNumber == selectedSeasonDetails?.seasonNumber })
                                        }
                                    }
                                ))
                                .toggleStyle(CheckboxToggleStyle())
                            }
                            .listRowBackground(Color(white: 0.85))
                            .listRowSeparator(.hidden)
                        }
                        Button("Back to Seasons") { selectedSeasonDetails = nil }
                            .font(.caption)
                            .foregroundColor(.accentYellow)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(Color.retroGray)
                
                HStack {
                    Button("Back to Search") {
                        currentStep = .search
                        isSearchFieldFocused = true
                        selectedSeasonDetails = nil
                        detailShow = nil
                        tvDetails = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    if !selectedResults.isEmpty {
                        Button("Continue (\(selectedResults.count) items)") {
                            currentStep = .prioritySelection
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Step 3: Priority Selection
    private var prioritySelectionStepView: some View {
        VStack(spacing: 16) {
            Text("Select Priority:")
                .font(.subheadline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                priorityOption(value: 1, label: "1 - Must Watch Now")
                priorityOption(value: 2, label: "2 - Watch Soon")
                priorityOption(value: 3, label: "3 - Watch Later")
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Add All (\(selectedResults.count) items)") {
                    Task {
                        await viewModel.addItemsToWatchlist(selections: selectedResults, priority: selectedPriority)
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

extension AddWatchlistView {
    struct CheckboxToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .solidGreen : .darkGray)
                .font(.system(size: 22))
                .onTapGesture { configuration.isOn.toggle() }
        }
    }

    private func priorityOption(value: Int, label: String) -> some View {
        Button {
            selectedPriority = value
        } label: {
            HStack {
                Image(systemName: selectedPriority == value ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selectedPriority == value ? .accentYellow : .gray)
                Text(label)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedPriority == value ? Color.accentYellow : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentYellow)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.accentYellow)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.retroGray)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentYellow, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    // Create a mock repository and view model for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema([User.self, WatchlistItem.self, StreamingService.self, AppNotification.self]), configurations: config)
    
    let mockUser = User(tmdbApiKey: "mock_api_key")
    container.mainContext.insert(mockUser)
    
    let mockRepo = StreamSmarterRepository(modelContext: container.mainContext)
    let mockViewModel = WatchlistViewModel()
    mockViewModel.setup(repository: mockRepo)
    mockViewModel.user = mockUser
    
    // Simulate some search results
    mockViewModel.searchResults = [
        TmdbSearchResult(id: 1, mediaType: "movie", title: "Dune", name: nil, posterPath: nil, releaseDate: "2021-10-22", firstAirDate: nil, knownFor: nil),
        TmdbSearchResult(id: 2, mediaType: "tv", title: "Foundation", name: nil, posterPath: nil, releaseDate: nil, firstAirDate: "2021-09-24", knownFor: nil),
        TmdbSearchResult(id: 3, mediaType: "tv", title: "The Expanse", name: nil, posterPath: nil, releaseDate: nil, firstAirDate: "2015-12-14", knownFor: nil)
    ]
    
    return AddWatchlistView(viewModel: mockViewModel)
        .modelContainer(container)
}
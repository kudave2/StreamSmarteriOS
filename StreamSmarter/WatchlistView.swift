import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WatchlistViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items) { item in
                    WatchlistRow(item: item)
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.toggleWatched(item: item)
                            } label: {
                                Label(item.status == "Watched" ? "Unwatch" : "Watched", 
                                      systemImage: item.status == "Watched" ? "arrow.uturn.backward" : "check")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteItem(item: item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("My Watchlist")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StreamSmarterLogoView(iconSize: 20, fontSize: 18, taglineSize: 0)
                }
            }
            .onAppear {
                viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
            }
            .overlay {
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "Your Watchlist is Empty",
                        systemImage: "popcorn",
                        description: Text("Search for movies or shows to add them here.")
                    )
                }
            }
        }
    }
}

struct WatchlistRow: View {
    let item: WatchlistItem

    var body: some View {
        HStack(spacing: 12) {
            // AsyncImage replaces Glide/Picasso/Coil
            AsyncImage(url: URL(string: item.imageUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 90)
            .cornerRadius(4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(item.status == "Watched" ? .gray : .white)
                
                if let year = item.releaseYear {
                    Text(year)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(item.type.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if item.status == "Watched" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.status == "Watched" ? 0.6 : 1.0)
    }
}

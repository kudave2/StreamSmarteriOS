import SwiftUI
import SwiftData

struct OnboardingView: View {
    // MARK: - Environment & State
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
    @State private var viewModel = ProfileViewModel()
    @State private var currentPage = 0
    @FocusState private var focusedField: ProfileField?
    
    // MARK: - Constants
    private let mainServiceOptions = [
        "YouTube TV", "DirecTV Stream", "Hulu + Live TV",
        "Sling TV", "Fubo", "Cable", "Satellite", "Antenna", "Other"
    ]
    
    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            title: "Welcome to StreamSmarter",
            description: "Stop overpaying for streaming services. We help you track your watchlist and viewing habits to provide data-driven recommendations on what to keep active.",
            icon: "play.tv.fill",
            color: .brandBlue
        ),
        OnboardingPageData(
            title: "Your Priority Watchlist",
            description: "Add movies and TV shows with priority levels. Focus on 'Must Watch' content and let the app help you identify which services provide the best value for your time.",
            icon: "star.fill",
            color: .popcornYellow
        ),
        OnboardingPageData(
            title: "Smart Analysis",
            description: "Our 'Brains' analyze your list to suggest a 30-day timeline. We'll tell you when it's time to binge a service before it renews or when to suspend a service you aren't using.",
            icon: "chart.bar.xaxis",
            color: .solidGreen
        )
    ]
    
    enum ProfileField {
        case tmdbKey, hours, cost, mainService
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Spacer()
                    StreamSmarterLogoView(
                        iconSize: 32,
                        fontSize: 32,
                        taglineSize: 10
                    )
                    Spacer()
                }
                .padding()

                TabView(selection: $currentPage) {
                    // Info Pages
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingInfoPage(pages[index])
                            .tag(index)
                    }
                    
                    // Setup Page
                    setupPage
                        .tag(pages.count)
                    
                    // Final Instructions Page
                    instructionPage
                        .tag(pages.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .id(currentPage)
                
                // Navigation Button
                VStack(spacing: 16) {
                    if currentPage < pages.count {
                        Button(action: {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                currentPage += 1
                            }
                        }) {
                            Text("Continue")
                                .font(.headline.bold())
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentYellow)
                                .cornerRadius(12)
                        }
                    } else if currentPage == pages.count {
                        Button(action: {
                            Task {
                                // Ensure data is saved directly to the model context to bypass 
                                // potential premium restrictions in the ViewModel during initial setup
                                if let user = try? modelContext.fetch(FetchDescriptor<User>()).first {
                                    user.tmdbApiKey = viewModel.tmdbApiKey
                                    user.mainViewingService = viewModel.mainViewingService
                                    user.mainViewingServiceCost = Double(viewModel.mainViewingServiceCost) ?? 0.0
                                    user.streamingHoursPerMonth = Int(viewModel.streamingHoursPerMonth) ?? 60
                                }
                                await viewModel.updateProfile()
                                if !viewModel.showValidationError {
                                    var transaction = Transaction()
                                    transaction.animation = nil
                                    withTransaction(transaction) {
                                        currentPage += 1
                                    }
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isValidating {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Continue")
                                        .font(.headline.bold())
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.solidGreen)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            isOnboardingComplete = true
                        }) {
                            HStack {
                                if viewModel.isValidating {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Watch and Save!")
                                        .font(.headline.bold())
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.solidGreen)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(30)
            }
            .animation(nil, value: currentPage)
        }
        .alert("Configuration Error", isPresented: $viewModel.showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.validationErrorMessage)
        }
        .sheet(isPresented: $viewModel.showApiKeyInfo) {
            TmdbApiKeyInfoSheet()
        }
        .onAppear {
            viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
        }
    }
    
    private func onboardingInfoPage(_ page: OnboardingPageData) -> some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding(.bottom, 20)
            
            Text(page.title)
                .font(.title.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(page.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
        }
    }
    
    private var instructionPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 80))
                .foregroundColor(.accentYellow)
                .padding(.bottom, 20)
            
            Text("You're All Set!")
                .font(.title.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("To start saving money:\n\n1. Go to **Services** and add your current subscriptions.\n2. Go to **Watchlist** to add the movies and shows you want to see.\n\nWe'll handle the analysis from there!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(6)
        }
    }
    
    // MARK: - Setup Page
    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Final Setup")
                    .font(.title.bold())
                    .foregroundColor(.accentYellow)
                Text("Set your preferences to get the most accurate savings analysis.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Main Viewing Service
                mainServiceSection
                
                // Main Service Monthly Cost
                mainServiceCostSection
                
                // TMDB API Key
                tmdbKeySection
            }
            .padding(30)
        }
    }
    
    // MARK: - Setup Page Sections (Adapted from ProfileView)
    
    private var mainServiceCostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAIN SERVICE MONTHLY COST ($)")
                .font(.caption.bold())
                .foregroundColor(.brandBlue)
            profileTextField(
                placeholder: "0.00",
                text: $viewModel.mainViewingServiceCost,
                field: .cost,
                keyboardType: .decimalPad
            )
        }
    }
    
    private var tmdbKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TMDB API KEY")
                    .font(.caption.bold())
                    .foregroundColor(.brandBlue)
                Spacer()
                Button { viewModel.showApiKeyInfo = true } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.accentYellow)
                }
            }
            profileTextField(
                placeholder: "Enter your API key here",
                text: $viewModel.tmdbApiKey,
                field: .tmdbKey,
                keyboardType: .default
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            Link(
                "Get your key at themoviedb.org/settings/api",
                destination: URL(string: "https://www.themoviedb.org/settings/api")!
            )
            .font(.caption)
            .foregroundColor(.accentYellow)
        }
    }
    
    private var mainServiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAIN VIEWING SERVICE")
                .font(.caption.bold())
                .foregroundColor(.brandBlue)
            Menu {
                ForEach(mainServiceOptions, id: \.self) { option in
                    Button(option) { viewModel.mainViewingService = option }
                }
            } label: {
                HStack {
                    Text(viewModel.mainViewingService.isEmpty ? "Select a service" : viewModel.mainViewingService)
                        .foregroundColor(viewModel.mainViewingService.isEmpty ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.retroGray)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1.5))
            }
        }
    }
    
    // MARK: - Reusable Components (Adapted from ProfileView)
    
    private func profileTextField(
        placeholder: String,
        text: Binding<String>,
        field: ProfileField,
        keyboardType: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .keyboardType(keyboardType)
            .padding(12)
            .background(Color.retroGray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focusedField == field ? Color.accentYellow : Color.gray.opacity(0.5), lineWidth: 1.5)
            )
            .focused($focusedField, equals: field)
    }
}

struct OnboardingPageData {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - TmdbApiKeyInfoSheet (Moved from ProfileView to be accessible)
struct TmdbApiKeyInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Content identical to the one in ProfileView.swift
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("TMDB (The Movie Database) is a free, community-built movie and TV database.")
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        Text("1. ")
                            .foregroundColor(Color(white: 0.8))
                        Link("Create a free TMDB account", destination: URL(string: "https://www.themoviedb.org/signup")!)
                            .foregroundColor(.blue)
                            .underline(true, color: .blue)
                    }
                    Text("2. Go to Settings → API")
                    Text("3. Request an API key (Developer)")
                    Text("4. Copy the API Key (v3 auth)")
                }
                .foregroundColor(Color(white: 0.8))

                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("About TMDB API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.accentYellow)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
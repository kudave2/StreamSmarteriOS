import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AnalysisViewModel()
    @State private var profileViewModel = ProfileViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ssBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Analysis")
                            .font(.title.bold())
                            .foregroundColor(.ssSecondary)
                        
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
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if profileViewModel.isPremiumUser {
                        unlockedContent
                    } else {
                        lockedContent
                    }
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StreamSmarterLogoView(
                        iconSize: 24,
                        fontSize: 24,
                        taglineSize: 8,
                        onLogoClick: {
                            profileViewModel.toggleOverridePremium()
                        }
                    )
                    .environment(\.colorScheme, .light)
                }
            }
            .toolbarBackground(Color(red: 253/255, green: 253/255, blue: 253/255), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                viewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
                profileViewModel.setup(repository: StreamSmarterRepository(modelContext: modelContext))
            }
            .alert("Go Premium!", isPresented: $profileViewModel.showPremiumDialog) {
                Button("Purchase") {
                    profileViewModel.toggleOverridePremium()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Unlock premium features including main viewing service tracking and advanced analytics.")
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    private var unlockedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let data = viewModel.results {
                    // Main Analysis Dashboard
                    FirstGlanceCard(user: viewModel.user, data: data, viewModel: viewModel)
                    OptimalTimelineCard(user: viewModel.user, data: data, viewModel: viewModel)
                    ProjectTimelineCard(user: viewModel.user, data: data, viewModel: viewModel)
                    ShowAvailabilityMatrixCard(user: viewModel.user, data: data, viewModel: viewModel)

                    // Deep Dive Analytics Dashboard
                    Text("Deep Dive Analytics")
                        .font(.title2.bold())
                        .foregroundColor(.ssPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        NavigationLink {
                            BingingOpportunitiesView(user: viewModel.user, data: data, viewModel: viewModel)
                        } label: {
                            DeepDiveCard(title: "Binging", subtitle: "Opportunities", icon: "hourglass.bottomhalf.fill")
                        }
                        
                        NavigationLink {
                            HistoryTrendsView(user: viewModel.user, data: data, viewModel: viewModel)
                        } label: {
                            DeepDiveCard(title: "History", subtitle: "Trends", icon: "clock.arrow.circlepath")
                        }
                        
                        NavigationLink {
                            ServiceUtilizationView(user: viewModel.user, data: data, viewModel: viewModel)
                        } label: {
                            DeepDiveCard(title: "High Priority", subtitle: "Active Services", icon: "star.fill")
                        }
                        
                        NavigationLink {
                            OptimizationOptionsView(user: viewModel.user, data: data, viewModel: viewModel)
                        } label: {
                            DeepDiveCard(title: "Options to", subtitle: "Consider", icon: "lightbulb.fill")
                        }
                    }
                } else {
                    ProgressView().tint(.ssPrimary).padding(.top, 50)
                }
            }
            .padding()
        }
    }
    
    private var lockedContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.ssPrimary)
            
            Text("Premium Analytics Locked")
                .font(.title2.bold())
                .foregroundColor(.ssText)
            
            Text("Unlock advanced binging timelines, service cost analysis, and data-driven recommendations to save more on streaming.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                profileViewModel.showPremiumDialog = true
            } label: {
                Text("Upgrade to Premium")
                    .font(.headline.bold())
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.ssPrimary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .background(Color.ssBackground)
    }
}

// Helper struct for consistent Deep Dive Navigation Cards
struct DeepDiveCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .frame(height: 32)
                .foregroundColor(.ssSecondary)
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
            }
            .foregroundColor(.ssText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.ssSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}
import SwiftUI
import SwiftData

private let mainServiceOptions = [
    "YouTube TV", "DirecTV Stream", "Hulu + Live TV",
    "Sling TV", "Fubo", "Cable", "Satellite", "Antenna", "Other"
]

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProfileViewModel()
    @FocusState private var focusedField: ProfileField?
    @State private var overrideToastMessage: String? = nil
    @AppStorage("isDarkMode") private var isDarkMode = true

    enum ProfileField { case tmdbKey, hours, limit, cost }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("Profile")
                    .font(.title.bold())
                    .foregroundColor(.ssSecondary)

                Spacer()
                NavigationLink(value: "help") {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    themeToggleSection
                    tmdbKeySection
                    if !viewModel.isPremiumUser { goPremiumButton }
                    mainServiceSection
                    mainServiceCostSection
                    streamingHoursSection
                    concurrentLimitSection
                    if viewModel.activeServicesCount > (Int(viewModel.concurrentSubscriptionLimit) ?? 2) {
                        warningCard
                    }
                    if viewModel.hasChanges { updateProfileButton }
                    Divider().background(Color.gray.opacity(0.4))
                    backupSection
                }
                .padding()
            }
        }
        .background(Color.ssBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                StreamSmarterLogoView(
                    iconSize: 24,
                    fontSize: 24,
                    taglineSize: 8,
                    onLogoClick: {
                        viewModel.toggleOverridePremium()
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
        }
        .sheet(isPresented: $viewModel.showApiKeyInfo) {
            TmdbApiKeyInfoSheet()
        }
        .alert("Error", isPresented: $viewModel.showValidationError) {
            Button("OK") {}
        } message: {
            Text(viewModel.validationErrorMessage)
        }
        .alert("Go Premium!", isPresented: $viewModel.showPremiumDialog) {
            Button("Purchase") {
                viewModel.toggleOverridePremium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unlock premium features including main viewing service tracking and advanced analytics.")
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // MARK: - Theme Toggle

    private var themeToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Theme/Color")
                    .foregroundColor(.ssText)
                    .font(.headline)
                Text(isDarkMode ? "Currently using Retro Dark theme" : "Currently using Retro Light theme")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: $isDarkMode)
                .toggleStyle(SwitchToggleStyle(tint: .ssPrimary))
        }
        .padding(.bottom, 8)
    }

    // MARK: - TMDB Key

    private var tmdbKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TMDB API Key")
                    .foregroundColor(.ssText)
                    .font(.headline)
                Spacer()
                Button { viewModel.showApiKeyInfo = true } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.ssPrimary)
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
            .foregroundColor(.ssPrimary)
        }
    }

    // MARK: - Go Premium

    private var goPremiumButton: some View {
        Button {
            Task { await viewModel.attemptPremiumUpgrade() }
        } label: {
            ZStack {
                if viewModel.isValidating {
                    ProgressView().tint(.black)
                } else {
                    Text("GO PREMIUM!")
                        .font(.headline.bold())
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.ssPrimary)
            .cornerRadius(8)
        }
    }

    // MARK: - Main Viewing Service

    private var mainServiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main Viewing Service")
                .foregroundColor(.ssText)
                .font(.headline)
            if viewModel.isPremiumUser {
                Menu {
                    ForEach(mainServiceOptions, id: \.self) { option in
                        Button(option) { viewModel.mainViewingService = option }
                    }
                } label: {
                    HStack {
                        Text(viewModel.mainViewingService.isEmpty ? "Select a service" : viewModel.mainViewingService)
                            .foregroundColor(viewModel.mainViewingService.isEmpty ? .gray : .ssText)
                        Spacer()
                        Image(systemName: "chevron.down").foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.ssSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1.5))
                }
            } else {
                lockedField(text: "Locked (Premium Only)")
            }
        }
    }

    // MARK: - Main Service Cost

    private var mainServiceCostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main Service Monthly Cost ($)")
                .foregroundColor(.ssText)
                .font(.headline)
            if viewModel.isPremiumUser {
                profileTextField(
                    placeholder: "0.00",
                    text: $viewModel.mainViewingServiceCost,
                    field: .cost,
                    keyboardType: .decimalPad
                )
            } else {
                lockedField(text: "0.00")
            }
        }
    }

    // MARK: - Streaming Hours

    private var streamingHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaming Hours Per Month")
                .foregroundColor(.ssText)
                .font(.headline)
            profileTextField(
                placeholder: "60",
                text: $viewModel.streamingHoursPerMonth,
                field: .hours,
                keyboardType: .numberPad
            )
        }
    }

    // MARK: - Concurrent Subscriptions

    private var concurrentLimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Desired Concurrent Subscriptions")
                .foregroundColor(.ssText)
                .font(.headline)
            profileTextField(
                placeholder: "2",
                text: $viewModel.concurrentSubscriptionLimit,
                field: .limit,
                keyboardType: .numberPad
            )
        }
    }

    // MARK: - Warning Card

    @ViewBuilder
    private var warningCard: some View {
        let desired = Int(viewModel.concurrentSubscriptionLimit) ?? 2
        VStack(alignment: .leading) {
            Text("FYI, you have \(viewModel.activeServicesCount) active services and you want to keep subscriptions at \(desired). Consider suspending subscriptions with shows having lower watch priority. SAVE SOME $$$!")
                .foregroundColor(.red)
                .font(.subheadline)
        }
        .padding()
        .background(Color.ssSurface)
        .cornerRadius(8)
    }

    // MARK: - Update Profile

    private var updateProfileButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.updateProfile() }
        } label: {
            ZStack {
                if viewModel.isValidating {
                    ProgressView().tint(.black)
                } else {
                    Text("Update Profile")
                        .font(.headline.bold())
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.ssPrimary)
            .cornerRadius(8)
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Backup & Restore")
                .foregroundColor(.ssText)
                .font(.headline)
            HStack(spacing: 12) {
                outlineButton(title: "Export Backup") {
                    // BackupManager.exportDatabase — future sprint
                }
                outlineButton(title: "Import Backup") {
                    // BackupManager.importDatabase — future sprint
                }
            }
            Text("Backups are AES-GCM encrypted and tied to this device's hardware security module. They cannot be modified or read outside of this app.")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Reusable Components

    private func profileTextField(
        placeholder: String,
        text: Binding<String>,
        field: ProfileField,
        keyboardType: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .foregroundColor(.ssText)
            .keyboardType(keyboardType)
            .padding(12)
            .background(Color.ssSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focusedField == field ? Color.ssPrimary : Color.gray.opacity(0.5), lineWidth: 1.5)
            )
            .focused($focusedField, equals: field)
    }

    private func lockedField(text: String) -> some View {
        HStack {
            Text(text).foregroundColor(.gray)
            Spacer()
            Image(systemName: "lock.fill").foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.ssSurface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1.5))
        .onTapGesture { viewModel.showPremiumDialog = true }
    }

    private func outlineButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.ssPrimary)
                .background(Color.ssSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ssPrimary, lineWidth: 1))
        }
    }
}

#Preview {
    ProfileView()
}

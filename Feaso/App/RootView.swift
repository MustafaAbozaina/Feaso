import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    private var authService = AuthService.shared
    private var syncService = SyncService.shared
    
    /// Track the previous businessId to detect changes
    @State private var previousBusinessId: String?
    
    /// Show loading if auth is loading OR if we're doing initial sync
    private var isLoading: Bool {
        authService.isLoading || (authService.isAuthenticated && syncService.isSyncing && syncService.lastSyncDate == nil)
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if authService.isAuthenticated {
                mainTabView
            } else {
                LoginView()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                SyncService.shared.stopSync()
                // Clear local data on logout to prevent data leakage between businesses
                LedgerService.clearAllData(in: modelContext)
                previousBusinessId = nil
            }
        }
        .onChange(of: authService.businessId) { oldValue, newValue in
            // If businessId changed (user switched businesses), clear old data first
            if let oldBizId = oldValue, let newBizId = newValue, oldBizId != newBizId {
                LedgerService.clearAllData(in: modelContext)
            }
            
            if let businessId = newValue, !businessId.isEmpty {
                previousBusinessId = businessId
                SyncService.shared.startSync()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && authService.isAuthenticated {
                Task {
                    await SyncService.shared.refresh()
                }
            }
        }
        .onAppear {
            // Handle case where user is already authenticated on app launch
            // (Firebase restored session from Keychain)
            if authService.isAuthenticated, let businessId = authService.businessId, !businessId.isEmpty {
                SyncService.shared.startSync()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text(String(localized: "Loading..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var mainTabView: some View {
        TabView {
            NavigationStack {
                SalesmenListView()
            }
            .tabItem {
                Label(String(localized: "Salesmen"), systemImage: "person.2.fill")
            }
            
            CollectionsView()
            .tabItem {
                Label(String(localized: "Collections"), systemImage: "banknote.fill")
            }
            
            NavigationStack {
                ProductsListView()
            }
            .tabItem {
                Label(String(localized: "Products"), systemImage: "shippingbox.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(String(localized: "Settings"), systemImage: "gearshape.fill")
            }
        }
        .tint(Color.Theme.accent)
    }
}

#Preview {
    RootView()
}

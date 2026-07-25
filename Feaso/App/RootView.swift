import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private var authService = AuthService.shared
    private var syncService = SyncService.shared
    
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
            }
        }
        .onChange(of: authService.businessId) { _, businessId in
            if let businessId, !businessId.isEmpty {
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

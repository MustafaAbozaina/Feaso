import Foundation
import SwiftData
import Observation

// MARK: - Sync Service (Facade)

/// The main entry point for data synchronization in the app.
/// This service wraps the sync provider, allowing easy swapping of implementations.
/// Views and services should use this, not the provider directly.
@Observable
final class SyncService {
    
    // MARK: - Singleton
    
    static let shared = SyncService()
    
    // MARK: - Provider
    
    private let provider: SyncProvider
    
    // MARK: - Refresh Trigger
    
    /// Incremented after each successful sync to trigger view refreshes
    private(set) var refreshTrigger: Int = 0
    
    // MARK: - Computed Properties
    
    var isSyncing: Bool { provider.isSyncing }
    var lastSyncDate: Date? { provider.lastSyncDate }
    var syncError: Error? { provider.syncError }
    
    var status: SyncStatus {
        if let error = syncError {
            return .error(error.localizedDescription)
        }
        if isSyncing {
            return .syncing
        }
        if let date = lastSyncDate {
            return .synced(date)
        }
        return .idle
    }
    
    // MARK: - Init
    
    /// Default uses pull-on-demand for cost efficiency.
    /// To use real-time listeners, change to FirebaseRealtimeSyncProvider.shared
    private init(provider: SyncProvider = FirebasePullSyncProvider.shared) {
        self.provider = provider
    }
    
    /// For testing: create with a mock provider
    static func forTesting(provider: SyncProvider) -> SyncService {
        SyncService(provider: provider)
    }
    
    // MARK: - Configuration
    
    func configure(with context: ModelContext) {
        provider.configure(with: context)
    }
    
    // MARK: - Sync Control
    
    func startSync() {
        guard AuthService.shared.isAuthenticated else { return }
        provider.startSync()
    }
    
    func stopSync() {
        provider.stopSync()
    }
    
    // MARK: - Push Operations
    
    /// Push a customer to remote storage
    func push(_ customer: Customer) async {
        guard AuthService.shared.isAuthenticated else { return }
        do {
            try await provider.push(customer)
        } catch {
            // Errors are captured in provider.syncError
            // Firestore SDK will retry when back online
        }
    }
    
    /// Push a product to remote storage
    func push(_ product: Product) async {
        guard AuthService.shared.isAuthenticated else { return }
        do {
            try await provider.push(product)
        } catch {
            // Firestore handles offline queueing
        }
    }
    
    /// Push a transaction (with items and installments) to remote storage
    func push(_ transaction: Transaction) async {
        guard AuthService.shared.isAuthenticated else { return }
        do {
            try await provider.push(transaction)
        } catch {
            // Firestore handles offline queueing
        }
    }
    
    /// Push an installment update to remote storage
    func push(_ installment: Installment) async {
        guard AuthService.shared.isAuthenticated else { return }
        do {
            try await provider.push(installment)
        } catch {
            // Firestore handles offline queueing
        }
    }
    
    /// Pull all remote data (for new device setup)
    func pullAllData() async {
        guard AuthService.shared.isAuthenticated else { return }
        do {
            try await provider.pullAllData()
        } catch {
            // Error captured in provider.syncError
        }
    }
    
    /// Refresh data from the server.
    /// Call this on app foreground, pull-to-refresh, or manual sync.
    func refresh() async {
        guard AuthService.shared.isAuthenticated else { return }
        
        // Check if provider supports refresh (pull-based providers)
        if let pullProvider = provider as? FirebasePullSyncProvider {
            await pullProvider.refreshFromServer()
        } else {
            // For realtime providers, just do a pull
            do {
                try await provider.pullAllData()
            } catch {
                // Error captured in provider.syncError
            }
        }
        
        // Trigger UI refresh
        await MainActor.run {
            refreshTrigger += 1
        }
    }
}

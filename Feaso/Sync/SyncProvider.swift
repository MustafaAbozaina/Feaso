import Foundation
import SwiftData

// MARK: - Sync Provider Protocol (Loosely Coupled)

/// Protocol defining data synchronization operations.
/// This abstraction allows swapping Firestore for another backend without changing app code.
protocol SyncProvider {
    /// Whether sync is currently active
    var isSyncing: Bool { get }
    
    /// The last successful sync date
    var lastSyncDate: Date? { get }
    
    /// Any sync error that occurred
    var syncError: Error? { get }
    
    /// Configure the sync provider with a SwiftData context
    func configure(with context: ModelContext)
    
    /// Start listening for remote changes and syncing local changes
    func startSync()
    
    /// Stop all sync operations
    func stopSync()
    
    /// Push a customer to the remote store
    func push(_ customer: Customer) async throws
    
    /// Push a product to the remote store
    func push(_ product: Product) async throws
    
    /// Push a transaction (with its items and installments) to the remote store
    func push(_ transaction: Transaction) async throws
    
    /// Push an installment update to the remote store
    func push(_ installment: Installment) async throws
    
    /// Pull all remote data into local SwiftData (for first-time setup on new device)
    func pullAllData() async throws
}

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(String)
    
    var localizedDescription: String {
        switch self {
        case .idle:
            return String(localized: "Not synced")
        case .syncing:
            return String(localized: "Syncing...")
        case .synced(let date):
            return String(localized: "Synced \(date.formatted(.relative(presentation: .named)))")
        case .error(let message):
            return String(localized: "Sync error: \(message)")
        }
    }
    
    var iconName: String {
        switch self {
        case .idle: return "icloud.slash"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }
    
    var color: String {
        switch self {
        case .idle: return "secondary"
        case .syncing: return "orange"
        case .synced: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case notAuthenticated
    case noBusinessId
    case networkError
    case dataConversionError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "You must be signed in to sync")
        case .noBusinessId:
            return String(localized: "No business ID found")
        case .networkError:
            return String(localized: "Network error. Changes will sync when connection returns.")
        case .dataConversionError:
            return String(localized: "Failed to convert data for sync")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

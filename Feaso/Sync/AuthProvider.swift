import Foundation

// MARK: - Auth Provider Protocol (Loosely Coupled)

/// Protocol defining authentication operations.
/// This abstraction allows swapping Firebase for another auth provider without changing app code.
protocol AuthProvider {
    /// The current authenticated user, if any
    var currentUser: AuthUser? { get }
    
    /// Whether a user is currently authenticated
    var isAuthenticated: Bool { get }
    
    /// Whether authentication state is still loading
    var isLoading: Bool { get }
    
    /// The business ID for the current user (for multi-tenant support)
    var businessId: String? { get }
    
    /// The role of the current user within their business
    var userRole: UserRole? { get }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws
    
    /// Sign out the current user
    func signOut() throws
    
    /// Send a password reset email
    func sendPasswordReset(to email: String) async throws
    
    /// Refresh the current user's claims (businessId, role)
    func refreshClaims() async
}

// MARK: - Auth User Model

/// A platform-agnostic representation of an authenticated user
struct AuthUser: Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    
    init(id: String, email: String? = nil, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}

// MARK: - User Role

/// Roles that determine what actions a user can perform within a business
enum UserRole: String, Codable, CaseIterable {
    case owner
    case manager
    case clerk
    
    var localizedName: String {
        switch self {
        case .owner: return String(localized: "Owner")
        case .manager: return String(localized: "Manager")
        case .clerk: return String(localized: "Clerk")
        }
    }
    
    // MARK: - Permissions
    
    var canAddProducts: Bool {
        self == .owner || self == .manager
    }
    
    var canEditProducts: Bool {
        self == .owner || self == .manager
    }
    
    var canDeleteProducts: Bool {
        self == .owner
    }
    
    var canAddSalesmen: Bool {
        self == .owner || self == .manager
    }
    
    var canDeleteSalesmen: Bool {
        self == .owner
    }
    
    var canCreateTransactions: Bool {
        true // All roles can create transactions
    }
    
    var canReverseTransactions: Bool {
        self == .owner || self == .manager
    }
    
    var canViewReports: Bool {
        self == .owner || self == .manager
    }
    
    var canManageTeam: Bool {
        self == .owner
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return String(localized: "Invalid email or password")
        case .userNotFound:
            return String(localized: "No account found with this email")
        case .emailAlreadyInUse:
            return String(localized: "This email is already registered")
        case .weakPassword:
            return String(localized: "Password must be at least 6 characters")
        case .networkError:
            return String(localized: "Network error. Please check your connection.")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

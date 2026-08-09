import Foundation
import Observation

// MARK: - Auth Service (Facade)

/// The main entry point for authentication in the app.
/// This service wraps the auth provider, allowing easy swapping of implementations.
/// Views should use this service, not the provider directly.
@Observable
final class AuthService {
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    // MARK: - Provider (can be swapped for testing or different backends)
    
    private let provider: AuthProvider
    
    // MARK: - Computed Properties (delegate to provider)
    
    var currentUser: AuthUser? { provider.currentUser }
    var isAuthenticated: Bool { provider.isAuthenticated }
    var isLoading: Bool { provider.isLoading }
    var businessId: String? { provider.businessId }
    var userRole: UserRole? { provider.userRole }
    
    /// Convenience: current user's ID
    var uid: String? { currentUser?.id }
    
    /// Convenience: current user's email
    var email: String? { currentUser?.email }
    
    /// Convenience: current user's display name
    var displayName: String? { currentUser?.displayName }
    
    // MARK: - Init
    
    private init(provider: AuthProvider = FirebaseAuthProvider.shared) {
        self.provider = provider
    }
    
    /// For testing: create with a mock provider
    static func forTesting(provider: AuthProvider) -> AuthService {
        AuthService(provider: provider)
    }
    
    // MARK: - Actions
    
    func signIn(email: String, password: String) async throws {
        try await provider.signIn(email: email, password: password)
    }
    
    func signOut() throws {
        try provider.signOut()
    }
    
    func sendPasswordReset(to email: String) async throws {
        try await provider.sendPasswordReset(to: email)
    }
    
    func refreshClaims() async {
        await provider.refreshClaims()
    }
}

import Foundation
import FirebaseAuth
import Observation

// MARK: - Firebase Auth Provider Implementation

/// Firebase implementation of AuthProvider protocol.
/// This class handles all Firebase-specific authentication logic.
@Observable
final class FirebaseAuthProvider: AuthProvider {
    
    // MARK: - Singleton
    
    static let shared = FirebaseAuthProvider()
    
    // MARK: - Published State
    
    private(set) var currentUser: AuthUser?
    private(set) var isAuthenticated = false
    private(set) var isLoading = true
    private(set) var businessId: String?
    private(set) var userRole: UserRole?
    
    // MARK: - Private
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var firebaseUser: User?
    
    // MARK: - Init
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            
            self.firebaseUser = user
            
            if let user {
                self.currentUser = AuthUser(
                    id: user.uid,
                    email: user.email,
                    displayName: user.displayName
                )
                self.isAuthenticated = true
                
                // Fetch custom claims (businessId, role)
                Task { await self.refreshClaims() }
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
                self.businessId = nil
                self.userRole = nil
                self.isLoading = false
            }
        }
    }
    
    // MARK: - AuthProvider Protocol
    
    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
            businessId = nil
            userRole = nil
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    func sendPasswordReset(to email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    func refreshClaims() async {
        guard let user = firebaseUser else {
            isLoading = false
            return
        }
        
        do {
            // Force refresh to get latest claims
            let tokenResult = try await user.getIDTokenResult(forcingRefresh: true)
            
            // Extract businessId - for MVP, use uid as businessId
            if let bizId = tokenResult.claims["businessId"] as? String {
                self.businessId = bizId
            } else {
                // Fallback: use user's uid as businessId (single owner mode)
                self.businessId = user.uid
            }
            
            // Extract role - default to owner for MVP
            if let roleString = tokenResult.claims["role"] as? String,
               let role = UserRole(rawValue: roleString) {
                self.userRole = role
            } else {
                // Default to owner if no role claim (MVP single owner)
                self.userRole = .owner
            }
            
        } catch {
            // If claims fail, still allow access with defaults (offline support)
            self.businessId = user.uid
            self.userRole = .owner
        }
        
        isLoading = false
    }
    
    // MARK: - Error Mapping
    
    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard error.domain == AuthErrorDomain else {
            return .unknown(error)
        }
        
        switch AuthErrorCode(rawValue: error.code) {
        case .wrongPassword, .invalidCredential:
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error)
        }
    }
}

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

// MARK: - Firebase Auth Provider Implementation

/// Firebase implementation of AuthProvider protocol.
/// This class handles all Firebase-specific authentication logic.
/// After authentication, fetches user profile from /users/{uid} to get businessId and role.
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
    private let db = Firestore.firestore()
    
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
        
        print("🔐 [AUTH] refreshClaims() for user: \(user.uid)")
        
        do {
            // First, try to fetch user profile from Firestore /users/{uid}
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            print("🔐 [AUTH] User doc exists: \(userDoc.exists)")
            
            if userDoc.exists {
                // Document exists - try to decode it
                do {
                    let firestoreUser = try userDoc.data(as: FirestoreUser.self)
                    // User document decoded successfully - use businessId and role from Firestore
                    self.businessId = firestoreUser.businessId
                    print("🔐 [AUTH] ✅ Got businessId from user doc: \(firestoreUser.businessId)")
                    if let role = UserRole(rawValue: firestoreUser.role) {
                        self.userRole = role
                    } else {
                        self.userRole = .clerk // Default to clerk if unknown role
                    }
                } catch {
                    // Document exists but failed to decode - log error and use fallback
                    print("⚠️ [AUTH] Failed to decode user document: \(error)")
                    // Try to extract businessId directly from document data
                    let data = userDoc.data()
                    print("🔐 [AUTH] Raw document data keys: \(String(describing: data?.keys))")
                    
                    // Try to find businessId - check for common key variations
                    var bizId: String?
                    if let data {
                        // Try exact match first
                        bizId = data["businessId"] as? String
                        // If not found, search for any key containing "business" (handles invisible chars)
                        if bizId == nil {
                            for (key, value) in data {
                                if key.lowercased().contains("business") && key.lowercased().contains("id") {
                                    bizId = value as? String
                                    print("🔐 [AUTH] Found businessId with key '\(key)': \(bizId ?? "nil")")
                                    break
                                }
                            }
                        }
                    }
                    
                    if let bizId {
                        self.businessId = bizId
                        print("🔐 [AUTH] ✅ Got businessId from raw data: \(bizId)")
                        if let data,
                           let roleStr = data["role"] as? String,
                           let role = UserRole(rawValue: roleStr) {
                            self.userRole = role
                        } else {
                            self.userRole = .owner
                        }
                    } else {
                        // Can't read businessId - DO NOT use uid as fallback
                        // Leave businessId as nil to prevent creating wrong business
                        print("❌ [AUTH] Could not read businessId from user doc - leaving nil")
                        self.businessId = nil
                        self.userRole = nil
                    }
                }
            } else {
                // No user document exists - this is a new user, create business and user doc
                print("🔐 [AUTH] No user doc - creating new business for user")
                try await setupNewUserBusiness(user: user)
            }
            
        } catch {
            // Network error fetching user doc
            print("❌ [AUTH] Error fetching user doc: \(error)")
            // DO NOT fallback to uid - leave businessId nil and retry later
            self.businessId = nil
            self.userRole = nil
        }
        
        isLoading = false
        print("🔐 [AUTH] Final businessId: \(self.businessId ?? "nil")")
    }
    
    // MARK: - New User Setup
    
    /// Creates a new business and user document for first-time users.
    /// This sets up the multi-user business structure automatically.
    private func setupNewUserBusiness(user: User) async throws {
        // Generate a new business ID
        let businessRef = db.collection("businesses").document()
        let newBusinessId = businessRef.documentID
        
        // Create the business document
        let business = FirestoreBusiness(
            name: "My Business", // Default name, user can change later
            ownerId: user.uid
        )
        try businessRef.setData(from: business)
        
        // Create the user document linked to this business
        let firestoreUser = FirestoreUser(
            email: user.email,
            displayName: user.displayName,
            businessId: newBusinessId,
            role: UserRole.owner.rawValue
        )
        try db.collection("users").document(user.uid).setData(from: firestoreUser)
        
        // Update local state
        self.businessId = newBusinessId
        self.userRole = .owner
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

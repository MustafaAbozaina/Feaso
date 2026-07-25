import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Logo and welcome
                    headerSection
                    
                    // Login form
                    formSection
                    
                    // Error message
                    if let error = errorMessage {
                        errorSection(error)
                    }
                    
                    // Sign in button
                    signInButton
                    
                    // Forgot password
                    forgotPasswordButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Sign In"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.Theme.accent)
            
            Text("Feaso")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(String(localized: "Sign in to sync your data"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xl)
    }
    
    private var formSection: some View {
        VStack(spacing: Spacing.md) {
            // Email field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String(localized: "Email"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField(String(localized: "Email"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
            
            // Password field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String(localized: "Password"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                SecureField(String(localized: "Password"), text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .foregroundStyle(.red)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var signInButton: some View {
        Button(action: signIn) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(String(localized: "Sign In"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSignIn ? Color.Theme.accent : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .disabled(!canSignIn || isLoading)
    }
    
    private var forgotPasswordButton: some View {
        Button(action: { showForgotPassword = true }) {
            Text(String(localized: "Forgot Password?"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.accent)
        }
    }
    
    // MARK: - Logic
    
    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
    
    private func signIn() {
        guard canSignIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                // Success - AuthService state change will update UI
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}

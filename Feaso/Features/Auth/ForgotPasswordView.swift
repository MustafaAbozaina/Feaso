import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Icon and description
                    headerSection
                    
                    // Email field
                    emailField
                    
                    // Error message
                    if let error = errorMessage {
                        errorSection(error)
                    }
                    
                    // Success message
                    if showSuccess {
                        successSection
                    }
                    
                    // Send button
                    sendButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Reset Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.Theme.accent)
            
            Text(String(localized: "Forgot your password?"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(String(localized: "Enter your email and we'll send you a link to reset your password."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Spacing.lg)
    }
    
    private var emailField: some View {
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
    
    private var successSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(String(localized: "Reset link sent! Check your email."))
                .foregroundStyle(.green)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var sendButton: some View {
        Button(action: sendResetLink) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(String(localized: "Send Reset Link"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSend ? Color.Theme.accent : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .disabled(!canSend || isLoading || showSuccess)
    }
    
    // MARK: - Logic
    
    private var canSend: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty && trimmedEmail.contains("@")
    }
    
    private func sendResetLink() {
        guard canSend else { return }
        
        isLoading = true
        errorMessage = nil
        showSuccess = false
        
        Task {
            do {
                try await AuthService.shared.sendPasswordReset(
                    to: email.trimmingCharacters(in: .whitespaces)
                )
                showSuccess = true
                
                // Auto-dismiss after success
                try? await Task.sleep(for: .seconds(2))
                dismiss()
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
    ForgotPasswordView()
}

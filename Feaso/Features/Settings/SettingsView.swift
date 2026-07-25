import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = SettingsManager.shared
    private var authService = AuthService.shared
    @State private var showLanguageChangeAlert = false
    @State private var showSignOutConfirmation = false
    @State private var workWeekStart: Weekday = WorkWeekManager.workWeekStart
    @State private var workWeekEnd: Weekday = WorkWeekManager.workWeekEnd
    
    var body: some View {
        List {
            // MARK: - Account Section
            Section {
                SyncStatusRow()
                
                if authService.isAuthenticated {
                    if let email = authService.email {
                        HStack {
                            Text(String(localized: "Signed in as"))
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Text(String(localized: "Sign Out"))
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            } header: {
                Text("Account")
                    .font(.custom("SF Pro Text", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.Theme.ink2)
            }
            
            // MARK: - Language Section
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        if language != settings.selectedLanguage {
                            settings.selectedLanguage = language
                            showLanguageChangeAlert = true
                        }
                    } label: {
                        HStack {
                            Text(language.localizedName)
                                .foregroundStyle(Color.Theme.ink)
                            
                            Spacer()
                            
                            if language == settings.selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.Theme.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } header: {
                Text("Language")
                    .font(.custom("SF Pro Text", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.Theme.ink2)
            } footer: {
                Text("Restart the app for language changes to take effect.")
                    .font(.custom("SF Pro Text", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            // MARK: - Currency Section
            Section {
                // Egyptian Pound
                currencyRow(for: .egp)
                
                // US Dollar
                currencyRow(for: .usd)
            } header: {
                Text("Currency")
                    .font(.custom("SF Pro Text", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.Theme.ink2)
            }
            
            // MARK: - Work Week Section
            Section {
                Picker(String(localized: "Start Day"), selection: $workWeekStart) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.localizedName).tag(day)
                    }
                }
                .onChange(of: workWeekStart) { _, newValue in
                    WorkWeekManager.workWeekStart = newValue
                }
                
                Picker(String(localized: "End Day"), selection: $workWeekEnd) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.localizedName).tag(day)
                    }
                }
                .onChange(of: workWeekEnd) { _, newValue in
                    WorkWeekManager.workWeekEnd = newValue
                }
            } header: {
                Text("Work Week")
                    .font(.custom("SF Pro Text", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.Theme.ink2)
            } footer: {
                Text("Used to calculate \"This Week\" in Collections.")
                    .font(.custom("SF Pro Text", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.Theme.background)
        .scrollContentBackground(.hidden)
        .navigationTitle(String(localized: "Settings"))
        .alert(String(localized: "Restart Required"), isPresented: $showLanguageChangeAlert) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text("Please restart the app for the language change to take effect.")
        }
        .alert(String(localized: "Sign Out?"), isPresented: $showSignOutConfirmation) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Sign Out"), role: .destructive) {
                signOut()
            }
        } message: {
            Text("Your data will remain on this device but will stop syncing.")
        }
    }
    
    private func signOut() {
        do {
            try authService.signOut()
        } catch {
            // Error handling - user stays signed in
        }
    }
    
    @ViewBuilder
    private func currencyRow(for currency: Currency) -> some View {
        Button {
            settings.selectedCurrency = currency
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.localizedName)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Text(currency.symbol)
                        .font(.custom("SF Pro Text", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.Theme.ink3)
                }
                
                Spacer()
                
                if currency == settings.selectedCurrency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.Theme.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

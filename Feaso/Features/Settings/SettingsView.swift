import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = SettingsManager.shared
    @State private var showLanguageChangeAlert = false
    
    var body: some View {
        List {
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

import Foundation
import SwiftUI

@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    private let currencyKey = "selectedCurrency"
    private let languageKey = "selectedLanguage"
    private let lastProductUnitKey = "lastSelectedProductUnit"
    
    var selectedCurrency: Currency {
        didSet {
            UserDefaults.standard.set(selectedCurrency.rawValue, forKey: currencyKey)
        }
    }
    
    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            applyLanguage(selectedLanguage)
        }
    }
    
    /// The last selected product unit, used as default when creating new products
    var lastSelectedProductUnit: ProductUnit {
        didSet {
            UserDefaults.standard.set(lastSelectedProductUnit.rawValue, forKey: lastProductUnitKey)
        }
    }
    
    private init() {
        // Load saved currency or default to EGP
        if let savedCurrency = UserDefaults.standard.string(forKey: currencyKey),
           let currency = Currency(rawValue: savedCurrency) {
            self.selectedCurrency = currency
        } else {
            self.selectedCurrency = .egp
        }
        
        // Load saved language or default to system
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
        
        // Load saved product unit or default to piece
        if let savedUnit = UserDefaults.standard.string(forKey: lastProductUnitKey),
           let unit = ProductUnit(rawValue: savedUnit) {
            self.lastSelectedProductUnit = unit
        } else {
            self.lastSelectedProductUnit = .piece
        }
    }
    
    private func applyLanguage(_ language: AppLanguage) {
        let languageCode: String?
        switch language {
        case .system:
            languageCode = nil
        case .english:
            languageCode = "en"
        case .arabic:
            languageCode = "ar"
        }
        
        if let code = languageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case arabic = "ar"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .system: return String(localized: "System Default")
        case .english: return String(localized: "English")
        case .arabic: return String(localized: "العربية")
        }
    }
}



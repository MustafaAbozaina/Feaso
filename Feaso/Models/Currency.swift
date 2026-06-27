import Foundation

enum Currency: String, CaseIterable, Codable, Identifiable {
    case egp = "EGP"
    case usd = "USD"
    case sar = "SAR"
    case aed = "AED"
    case kwd = "KWD"
    case bhd = "BHD"
    case omr = "OMR"
    case qar = "QAR"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .egp: return String(localized: "Egyptian Pound (EGP)")
        case .usd: return String(localized: "US Dollar (USD)")
        case .sar: return String(localized: "Saudi Riyal (SAR)")
        case .aed: return String(localized: "UAE Dirham (AED)")
        case .kwd: return String(localized: "Kuwaiti Dinar (KWD)")
        case .bhd: return String(localized: "Bahraini Dinar (BHD)")
        case .omr: return String(localized: "Omani Rial (OMR)")
        case .qar: return String(localized: "Qatari Riyal (QAR)")
        }
    }
    
    var symbol: String {
        switch self {
        case .egp: return "E£"
        case .usd: return "$"
        case .sar: return "SR"
        case .aed: return "AED"
        case .kwd: return "KD"
        case .bhd: return "BD"
        case .omr: return "OMR"
        case .qar: return "QR"
        }
    }
    
    var localizedSymbol: String {
        String(localized: String.LocalizationValue(rawValue))
    }
    
    // Group currencies for picker display
    static var egyptianCurrency: [Currency] { [.egp] }
    static var westernCurrency: [Currency] { [.usd] }
    static var gulfCurrencies: [Currency] { [.sar, .aed, .kwd, .bhd, .omr, .qar] }
}

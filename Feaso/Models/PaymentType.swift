import Foundation

enum PaymentType: String, Codable, CaseIterable {
    case cash
    case installment
    
    var localizedName: String {
        switch self {
        case .cash:
            return String(localized: "Cash")
        case .installment:
            return String(localized: "Installment")
        }
    }
    
    /// Short name for badges and compact UI
    var shortName: String {
        switch self {
        case .cash:
            return String(localized: "Cash")
        case .installment:
            return String(localized: "Inst.", comment: "Short for Installment")
        }
    }
}

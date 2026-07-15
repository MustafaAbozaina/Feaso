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
}

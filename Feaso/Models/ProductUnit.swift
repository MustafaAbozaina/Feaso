import Foundation

/// Defines the unit of measurement for a product's quantity.
/// This determines how quantities are displayed and how the stepper behaves.
enum ProductUnit: String, Codable, CaseIterable, Identifiable {
    case piece
    case liter
    case kilogram
    case meter
    case box
    case dozen
    
    var id: String { rawValue }
    
    /// Localized display name for the unit
    var localizedName: String {
        switch self {
        case .piece: return String(localized: "Piece")
        case .liter: return String(localized: "Liter")
        case .kilogram: return String(localized: "Kilogram")
        case .meter: return String(localized: "Meter")
        case .box: return String(localized: "Box")
        case .dozen: return String(localized: "Dozen")
        }
    }
    
    /// Abbreviated unit symbol for display
    var symbol: String {
        switch self {
        case .piece: return String(localized: "pc")
        case .liter: return String(localized: "L")
        case .kilogram: return String(localized: "kg")
        case .meter: return String(localized: "m")
        case .box: return String(localized: "box")
        case .dozen: return String(localized: "dz")
        }
    }
    
    /// Whether this unit allows fractional quantities
    var allowsDecimals: Bool {
        switch self {
        case .piece, .box, .dozen:
            return false
        case .liter, .kilogram, .meter:
            return true
        }
    }
    
    /// Default step size for the quantity stepper
    var defaultStep: Decimal {
        switch self {
        case .piece, .box, .dozen:
            return 1
        case .liter, .kilogram:
            return Decimal(string: "0.5") ?? Decimal(1)
        case .meter:
            return Decimal(string: "0.25") ?? Decimal(1)
        }
    }
    
    /// Number of decimal places to display for this unit
    var decimalPlaces: Int {
        switch self {
        case .piece, .box, .dozen:
            return 0
        case .liter, .kilogram:
            return 2
        case .meter:
            return 2
        }
    }
    
    /// Formats a quantity according to this unit's display rules
    func format(_ quantity: Decimal) -> String {
        if allowsDecimals {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = decimalPlaces
            formatter.numberStyle = .decimal
            return formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
        } else {
            return "\(Int(truncating: quantity as NSDecimalNumber))"
        }
    }
    
    /// Formats quantity with unit symbol (e.g., "2.5 L" or "10 pc")
    func formatWithSymbol(_ quantity: Decimal) -> String {
        "\(format(quantity)) \(symbol)"
    }
}

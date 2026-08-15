import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    /// Formats amount as a number string (without currency symbol)
    static func string(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    /// Returns the current currency symbol (localized)
    static var symbol: String {
        SettingsManager.shared.selectedCurrency.localizedSymbol
    }
}

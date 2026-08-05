import Foundation

struct LineDraft: Identifiable {
    let id = UUID()
    let product: Product
    let productName: String
    let productCurrentStock: Decimal
    let productUnit: ProductUnit
    var quantity: Decimal
    var paymentType: PaymentType
    
    /// Custom unit price for this line item only. If nil, uses the default product price.
    var unitPriceOverride: Decimal?
    
    init(product: Product, quantity: Decimal, paymentType: PaymentType = .cash, unitPriceOverride: Decimal? = nil) {
        self.product = product
        self.productName = product.name
        self.productCurrentStock = product.currentStock
        self.productUnit = product.unit
        self.quantity = quantity
        self.paymentType = paymentType
        self.unitPriceOverride = unitPriceOverride
    }
    
    /// The default unit price based on payment type (before any override)
    var defaultUnitPrice: Decimal {
        paymentType == .cash ? product.cashPrice : product.installmentPrice
    }
    
    /// The actual unit price used for this line (override if set, otherwise default)
    var unitPrice: Decimal {
        unitPriceOverride ?? defaultUnitPrice
    }
    
    var lineTotal: Decimal {
        quantity * unitPrice
    }
    
    var exceedsStock: Bool {
        quantity > productCurrentStock
    }
    
    var formattedQuantity: String {
        productUnit.format(quantity)
    }
    
    var formattedStock: String {
        productUnit.formatWithSymbol(productCurrentStock)
    }
    
    /// Returns true if a custom price override is set
    var hasCustomPrice: Bool {
        unitPriceOverride != nil
    }
    
    /// The discount percentage (0-100). Positive means discount, negative means markup.
    /// Returns nil if no custom price is set.
    var discountPercentage: Decimal? {
        guard let override = unitPriceOverride, defaultUnitPrice > 0 else { return nil }
        let discount = ((defaultUnitPrice - override) / defaultUnitPrice) * 100
        return discount
    }
    
    /// Formatted discount text for display (e.g., "20% off" or "10% markup")
    var discountDisplayText: String? {
        guard let percentage = discountPercentage else { return nil }
        if percentage > 0 {
            return String(localized: "\(NSDecimalNumber(decimal: percentage.rounded(scale: 1)).intValue)% off")
        } else if percentage < 0 {
            let markup = abs(percentage)
            return String(localized: "\(NSDecimalNumber(decimal: markup.rounded(scale: 1)).intValue)% markup")
        }
        return nil
    }
}

// MARK: - Decimal Extension for Rounding

extension Decimal {
    func rounded(scale: Int, roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, roundingMode)
        return result
    }
}

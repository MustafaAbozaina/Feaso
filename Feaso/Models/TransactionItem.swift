import Foundation
import SwiftData

@Model
final class TransactionItem {
    var id: UUID
    var quantity: Decimal
    var unitPrice: Decimal
    
    var transaction: Transaction?
    var product: Product?
    
    /// Initialize with explicit unit price override (used for returns with historical pricing)
    init(product: Product, quantity: Decimal, unitPriceOverride: Decimal? = nil) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.unitPrice = unitPriceOverride ?? product.cashPrice
    }
    
    /// Initialize with payment type to determine price (used for distributions)
    init(product: Product, quantity: Decimal, paymentType: PaymentType) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.unitPrice = paymentType == .cash ? product.cashPrice : product.installmentPrice
    }
    
    var lineTotal: Decimal {
        quantity * unitPrice
    }
    
    /// Formats the quantity using the product's unit
    var formattedQuantity: String {
        product?.unit.format(quantity) ?? "\(quantity)"
    }
    
    /// Formats the quantity with unit symbol
    var formattedQuantityWithSymbol: String {
        product?.unit.formatWithSymbol(quantity) ?? "\(quantity)"
    }
}

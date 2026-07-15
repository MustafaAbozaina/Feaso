import Foundation
import SwiftData

@Model
final class TransactionItem {
    var id: UUID
    var quantity: Int
    var unitPrice: Decimal
    
    var transaction: Transaction?
    var product: Product?
    
    /// Initialize with explicit unit price override (used for returns with historical pricing)
    init(product: Product, quantity: Int, unitPriceOverride: Decimal? = nil) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.unitPrice = unitPriceOverride ?? product.cashPrice
    }
    
    /// Initialize with payment type to determine price (used for distributions)
    init(product: Product, quantity: Int, paymentType: PaymentType) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.unitPrice = paymentType == .cash ? product.cashPrice : product.installmentPrice
    }
    
    var lineTotal: Decimal {
        Decimal(quantity) * unitPrice
    }
}

import Foundation
import SwiftData

@Model
final class TransactionItem {
    var id: UUID
    var quantity: Int
    var unitPrice: Decimal
    
    var transaction: Transaction?
    var product: Product?
    
    init(product: Product, quantity: Int, unitPriceOverride: Decimal? = nil) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.unitPrice = unitPriceOverride ?? product.sellingPrice
    }
    
    var lineTotal: Decimal {
        Decimal(quantity) * unitPrice
    }
}

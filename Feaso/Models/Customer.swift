import Foundation
import SwiftData

@Model
final class Customer {
    var id: UUID
    var name: String
    var phone: String?
    var notes: String?
    var createdAt: Date
    var deletedAt: Date?
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.customer)
    var transactions: [Transaction] = []
    
    init(name: String, phone: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.notes = notes
        self.createdAt = .now
    }
    
    /// Computed balance. Positive = customer owes the business.
    /// Sums the full journal: a reversed transaction and its reversal cancel out.
    var balance: Decimal {
        transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    var isSettled: Bool { balance == 0 }
    var isActive: Bool { deletedAt == nil }
    
    var lastActivityAt: Date? {
        transactions.map(\.occurredAt).max()
    }
    
    /// Calculates how many units of each product the customer can still return.
    /// Formula: distributed quantity - already returned quantity (excluding reversed transactions)
    var returnableProducts: [Product: Int] {
        let activeTransactions = transactions.filter { $0.reversedBy == nil }
        
        var productQuantities: [UUID: (product: Product, quantity: Int)] = [:]
        
        for transaction in activeTransactions {
            for item in transaction.items {
                guard let product = item.product else { continue }
                
                let currentQuantity = productQuantities[product.id]?.quantity ?? 0
                
                switch transaction.type {
                case .distribution:
                    // Add to returnable quantity
                    productQuantities[product.id] = (product, currentQuantity + item.quantity)
                case .return:
                    // Subtract from returnable quantity
                    productQuantities[product.id] = (product, currentQuantity - item.quantity)
                default:
                    break
                }
            }
        }
        
        // Return only products with positive returnable quantity
        var result: [Product: Int] = [:]
        for (_, value) in productQuantities where value.quantity > 0 {
            result[value.product] = value.quantity
        }
        return result
    }
    
    /// Returns true if the customer has any products that can be returned
    var hasReturnableProducts: Bool {
        !returnableProducts.isEmpty
    }
}

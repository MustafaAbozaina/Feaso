import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var costPrice: Decimal
    var sellingPrice: Decimal
    var openingStock: Int
    var reorderThreshold: Int?
    var createdAt: Date
    var deletedAt: Date?
    
    @Relationship(inverse: \TransactionItem.product)
    var transactionItems: [TransactionItem] = []
    
    init(
        name: String,
        costPrice: Decimal,
        sellingPrice: Decimal,
        openingStock: Int = 0,
        reorderThreshold: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.costPrice = costPrice
        self.sellingPrice = sellingPrice
        self.openingStock = openingStock
        self.reorderThreshold = reorderThreshold
        self.createdAt = .now
    }
    
    /// Current stock = opening - distributed + returned + received, excluding reversed transactions.
    var currentStock: Int {
        let activeItems = transactionItems.filter {
            $0.transaction?.reversedBy == nil
        }
        let distributed = activeItems
            .filter { $0.transaction?.type == .distribution }
            .reduce(0) { $0 + $1.quantity }
        let returned = activeItems
            .filter { $0.transaction?.type == .return }
            .reduce(0) { $0 + $1.quantity }
        let received = activeItems
            .filter { $0.transaction?.type == .stockReceipt }
            .reduce(0) { $0 + $1.quantity }
        return openingStock - distributed + returned + received
    }
    
    var stockStatus: StockStatus {
        if currentStock <= 0 { return .outOfStock }
        if let threshold = reorderThreshold, currentStock <= threshold { return .low }
        return .healthy
    }
    
    var isActive: Bool { deletedAt == nil }
}

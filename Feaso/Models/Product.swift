import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var costPrice: Decimal
    var cashPrice: Decimal
    var installmentPrice: Decimal
    var openingStock: Decimal
    var reorderThreshold: Decimal?
    var unitRaw: String
    var createdAt: Date
    var deletedAt: Date?
    
    @Relationship(inverse: \TransactionItem.product)
    var transactionItems: [TransactionItem] = []
    
    /// The unit of measurement for this product
    var unit: ProductUnit {
        get { ProductUnit(rawValue: unitRaw) ?? .piece }
        set { unitRaw = newValue.rawValue }
    }
    
    init(
        name: String,
        costPrice: Decimal,
        cashPrice: Decimal,
        installmentPrice: Decimal? = nil,
        openingStock: Decimal = 0,
        reorderThreshold: Decimal? = nil,
        unit: ProductUnit = .piece
    ) {
        self.id = UUID()
        self.name = name
        self.costPrice = costPrice
        self.cashPrice = cashPrice
        self.installmentPrice = installmentPrice ?? cashPrice  // Default to cash price if not provided
        self.openingStock = openingStock
        self.reorderThreshold = reorderThreshold
        self.unitRaw = unit.rawValue
        self.createdAt = .now
    }
    
    /// Current stock = opening - distributed + returned + received, excluding reversed transactions.
    var currentStock: Decimal {
        let activeItems = transactionItems.filter {
            $0.transaction?.reversedBy == nil
        }
        let distributed = activeItems
            .filter { $0.transaction?.type == .distribution }
            .reduce(Decimal(0)) { $0 + $1.quantity }
        let returned = activeItems
            .filter { $0.transaction?.type == .return }
            .reduce(Decimal(0)) { $0 + $1.quantity }
        let received = activeItems
            .filter { $0.transaction?.type == .stockReceipt }
            .reduce(Decimal(0)) { $0 + $1.quantity }
        return openingStock - distributed + returned + received
    }
    
    var stockStatus: StockStatus {
        if currentStock <= 0 { return .outOfStock }
        if let threshold = reorderThreshold, currentStock <= threshold { return .low }
        return .healthy
    }
    
    var isActive: Bool { deletedAt == nil }
    
    /// Formats the current stock with the appropriate unit symbol
    var formattedStock: String {
        unit.formatWithSymbol(currentStock)
    }
}

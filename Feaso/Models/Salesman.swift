import Foundation
import SwiftData

@Model
final class Salesman {
    var id: UUID
    var name: String
    var phone: String?
    var notes: String?
    var createdAt: Date
    var deletedAt: Date?
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.salesman)
    var transactions: [Transaction] = []
    
    init(name: String, phone: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.notes = notes
        self.createdAt = .now
    }
    
    /// Computed balance. Positive = salesman owes the business.
    var balance: Decimal {
        transactions
            .filter { $0.reversedBy == nil }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    var isSettled: Bool { balance == 0 }
    var isActive: Bool { deletedAt == nil }
    
    var lastActivityAt: Date? {
        transactions.map(\.occurredAt).max()
    }
}

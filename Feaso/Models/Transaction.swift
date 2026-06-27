import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var typeRaw: String
    var amount: Decimal
    var occurredAt: Date
    var note: String?
    var createdAt: Date
    
    /// Stores the file name of the attached image (stored in app's documents directory)
    var attachmentFileName: String?
    
    var salesman: Salesman?
    
    @Relationship(deleteRule: .cascade, inverse: \TransactionItem.transaction)
    var items: [TransactionItem] = []
    
    var reversedBy: Transaction?
    var reverses: Transaction?
    
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .adjustment }
        set { typeRaw = newValue.rawValue }
    }
    
    init(
        type: TransactionType,
        amount: Decimal,
        salesman: Salesman,
        occurredAt: Date = .now,
        note: String? = nil,
        attachmentFileName: String? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.salesman = salesman
        self.occurredAt = occurredAt
        self.note = note
        self.attachmentFileName = attachmentFileName
        self.createdAt = .now
    }
    
    var isReversed: Bool { reversedBy != nil }
    var isReversal: Bool { reverses != nil }
    var hasAttachment: Bool { attachmentFileName != nil }
}

import Foundation
import SwiftData

enum LedgerError: Error {
    case alreadyReversed
    case missingSalesman
}

enum LedgerService {
    
    @MainActor
    static func recordDistribution(
        to salesman: Salesman,
        items: [(product: Product, quantity: Int)],
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let total = items.reduce(Decimal(0)) { sum, item in
            sum + (Decimal(item.quantity) * item.product.sellingPrice)
        }
        
        let transaction = Transaction(
            type: .distribution,
            amount: total,
            salesman: salesman,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName
        )
        context.insert(transaction)
        
        for (product, quantity) in items {
            let item = TransactionItem(product: product, quantity: quantity)
            item.transaction = transaction
            context.insert(item)
        }
        
        try context.save()
    }
    
    @MainActor
    static func recordPayment(
        from salesman: Salesman,
        amount: Decimal,
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let transaction = Transaction(
            type: .payment,
            amount: -amount,  // stored as negative to reduce balance
            salesman: salesman,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName
        )
        context.insert(transaction)
        try context.save()
    }
    
    @MainActor
    static func recordReturn(
        from salesman: Salesman,
        items: [(product: Product, quantity: Int)],
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        // Calculate total at selling price (reduces debt)
        let total = items.reduce(Decimal(0)) { sum, item in
            sum + (Decimal(item.quantity) * item.product.sellingPrice)
        }
        
        // Amount is negative because it reduces what salesman owes
        let transaction = Transaction(
            type: .return,
            amount: -total,
            salesman: salesman,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName
        )
        context.insert(transaction)
        
        // Create transaction items (for stock tracking and audit trail)
        for (product, quantity) in items {
            let item = TransactionItem(product: product, quantity: quantity)
            item.transaction = transaction
            context.insert(item)
        }
        
        try context.save()
    }
    
    @MainActor
    static func reverse(
        _ original: Transaction,
        in context: ModelContext
    ) throws {
        guard original.reversedBy == nil else {
            throw LedgerError.alreadyReversed
        }
        
        guard let salesman = original.salesman else {
            throw LedgerError.missingSalesman
        }
        
        let reversal = Transaction(
            type: .adjustment,
            amount: -original.amount,
            salesman: salesman,
            note: String(localized: "Reversal")
        )
        reversal.reverses = original
        original.reversedBy = reversal
        context.insert(reversal)
        try context.save()
    }
}

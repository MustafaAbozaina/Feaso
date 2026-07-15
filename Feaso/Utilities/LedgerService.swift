import Foundation
import SwiftData

enum LedgerError: Error {
    case alreadyReversed
    case missingSalesman
    case insufficientReturnableQuantity
}

/// A batch of units distributed at a single historical unit price.
struct PriceLot {
    let unitPrice: Decimal
    var quantity: Int
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
        let transactionItems = items.map { item in
            TransactionItem(product: item.product, quantity: item.quantity)
        }
        let total = transactionItems.reduce(Decimal(0)) { $0 + $1.lineTotal }

        let transaction = Transaction(
            type: .distribution,
            amount: total,
            salesman: salesman,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName
        )
        context.insert(transaction)

        for item in transactionItems {
            item.transaction = transaction
            context.insert(item)
        }

        try context.save()
    }

    @MainActor
    static func recordStockReceipt(
        items: [(product: Product, quantity: Int)],
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let transactionItems = items.map { item in
            TransactionItem(product: item.product, quantity: item.quantity)
        }
        // Use cost price for valuation of received stock
        let total = transactionItems.reduce(Decimal(0)) { sum, item in
            sum + (Decimal(item.quantity) * (item.product?.costPrice ?? 0))
        }

        let transaction = Transaction(
            type: .stockReceipt,
            amount: total,
            salesman: nil,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName
        )
        context.insert(transaction)

        for item in transactionItems {
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
        // Value every returned unit at the price it was distributed at (FIFO),
        // not the product's current price. Validate quantities before inserting
        // anything so a failed line leaves the ledger untouched.
        var transactionItems: [TransactionItem] = []
        for (product, quantity) in items {
            let lots = outstandingLots(for: salesman, product: product)
            let segments = try consume(quantity, from: lots)
            for segment in segments {
                transactionItems.append(TransactionItem(
                    product: product,
                    quantity: segment.quantity,
                    unitPriceOverride: segment.unitPrice
                ))
            }
        }

        let total = transactionItems.reduce(Decimal(0)) { $0 + $1.lineTotal }

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

        for item in transactionItems {
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

    // MARK: - Return Valuation

    /// Units of a product still in the salesman's hands, grouped by the unit price
    /// they were distributed at, oldest first. Prior returns consume lots FIFO.
    static func outstandingLots(for salesman: Salesman, product: Product) -> [PriceLot] {
        let activeTransactions = salesman.transactions
            .filter { $0.reversedBy == nil }
            .sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.createdAt < $1.createdAt
            }

        var lots: [PriceLot] = []
        var returnedQuantity = 0

        for transaction in activeTransactions {
            for item in transaction.items where item.product?.id == product.id {
                switch transaction.type {
                case .distribution:
                    lots.append(PriceLot(unitPrice: item.unitPrice, quantity: item.quantity))
                case .return:
                    returnedQuantity += item.quantity
                default:
                    break
                }
            }
        }

        return consumed(lots, by: returnedQuantity)
    }

    /// Value of returning `quantity` units against the given lots (FIFO).
    /// Used by the UI to preview totals; matches what `recordReturn` will record.
    static func value(of quantity: Int, from lots: [PriceLot]) -> Decimal {
        guard let segments = try? consume(quantity, from: lots) else {
            return Decimal(0)
        }
        return segments.reduce(Decimal(0)) { $0 + Decimal($1.quantity) * $1.unitPrice }
    }

    /// Splits `quantity` across lots FIFO, returning one segment per price consumed.
    private static func consume(_ quantity: Int, from lots: [PriceLot]) throws -> [PriceLot] {
        guard quantity > 0 else { return [] }

        var remaining = quantity
        var segments: [PriceLot] = []

        for lot in lots {
            guard remaining > 0 else { break }
            let taken = min(lot.quantity, remaining)
            if taken > 0 {
                segments.append(PriceLot(unitPrice: lot.unitPrice, quantity: taken))
                remaining -= taken
            }
        }

        guard remaining == 0 else {
            throw LedgerError.insufficientReturnableQuantity
        }
        return segments
    }

    /// Lots remaining after consuming `quantity` units FIFO.
    /// Excess quantity (possible if a distribution was reversed after a return)
    /// is ignored rather than over-stating what remains.
    private static func consumed(_ lots: [PriceLot], by quantity: Int) -> [PriceLot] {
        var remaining = quantity
        var result: [PriceLot] = []

        for lot in lots {
            let taken = min(lot.quantity, remaining)
            remaining -= taken
            if lot.quantity > taken {
                result.append(PriceLot(unitPrice: lot.unitPrice, quantity: lot.quantity - taken))
            }
        }

        return result
    }
}

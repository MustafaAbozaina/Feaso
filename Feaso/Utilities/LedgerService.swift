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

    /// Configuration for creating installment schedules
    struct InstallmentConfig {
        let numberOfInstallments: Int
        let firstDueDate: Date
        let intervalDays: Int
        
        /// Custom amounts for each installment (if nil, divides total evenly)
        let customAmounts: [Decimal]?
        
        /// Custom dates for each installment (if nil, uses interval calculation)
        let customDates: [Date]?
        
        init(numberOfInstallments: Int, firstDueDate: Date, interval: InstallmentInterval, customAmounts: [Decimal]? = nil, customDates: [Date]? = nil) {
            self.numberOfInstallments = numberOfInstallments
            self.firstDueDate = firstDueDate
            self.intervalDays = interval.rawValue
            self.customAmounts = customAmounts
            self.customDates = customDates
        }
        
        init(numberOfInstallments: Int, firstDueDate: Date, intervalDays: Int, customAmounts: [Decimal]? = nil, customDates: [Date]? = nil) {
            self.numberOfInstallments = numberOfInstallments
            self.firstDueDate = firstDueDate
            self.intervalDays = intervalDays
            self.customAmounts = customAmounts
            self.customDates = customDates
        }
    }
    
    @MainActor
    static func recordDistribution(
        to salesman: Salesman,
        items: [(product: Product, quantity: Int)],
        paymentType: PaymentType = .cash,
        installmentConfig: InstallmentConfig? = nil,
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let transactionItems = items.map { item in
            TransactionItem(product: item.product, quantity: item.quantity, paymentType: paymentType)
        }
        let total = transactionItems.reduce(Decimal(0)) { $0 + $1.lineTotal }

        let transaction = Transaction(
            type: .distribution,
            amount: total,
            salesman: salesman,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName,
            paymentType: paymentType
        )
        context.insert(transaction)

        for item in transactionItems {
            item.transaction = transaction
            context.insert(item)
        }
        
        // Create installments if configured and payment type is installment
        if paymentType == .installment, let config = installmentConfig {
            let installments = createInstallments(for: total, config: config, transaction: transaction)
            for installment in installments {
                context.insert(installment)
            }
        }

        try context.save()
        
        // Sync to Firestore - capture the transaction while still on main actor
        // to ensure relationships are properly resolved
        let transactionToSync = transaction
        Task {
            await SyncService.shared.push(transactionToSync)
        }
    }
    
    // MARK: - Installment Creation
    
    /// Creates installments for a transaction based on the configuration
    private static func createInstallments(
        for total: Decimal,
        config: InstallmentConfig,
        transaction: Transaction
    ) -> [Installment] {
        var installments: [Installment] = []
        let calendar = Calendar.current
        
        // Helper to get due date for an index
        func getDueDate(for index: Int) -> Date {
            if let customDates = config.customDates, index < customDates.count {
                return customDates[index]
            }
            return calendar.date(byAdding: .day, value: config.intervalDays * index, to: config.firstDueDate) ?? config.firstDueDate
        }
        
        if let customAmounts = config.customAmounts, customAmounts.count == config.numberOfInstallments {
            // Use custom amounts
            for (index, amount) in customAmounts.enumerated() {
                let dueDate = getDueDate(for: index)
                let installment = Installment(
                    sequenceNumber: index + 1,
                    amount: amount,
                    dueDate: dueDate,
                    transaction: transaction
                )
                installments.append(installment)
            }
        } else {
            // Divide total evenly
            let baseAmount = total / Decimal(config.numberOfInstallments)
            let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
            let remainder = total - (roundedBase * Decimal(config.numberOfInstallments))
            
            for index in 0..<config.numberOfInstallments {
                let dueDate = getDueDate(for: index)
                // Add remainder to the last installment
                let amount = index == config.numberOfInstallments - 1 ? roundedBase + remainder : roundedBase
                let installment = Installment(
                    sequenceNumber: index + 1,
                    amount: amount,
                    dueDate: dueDate,
                    transaction: transaction
                )
                installments.append(installment)
            }
        }
        
        return installments
    }
    
    /// Updates installments for an existing transaction
    @MainActor
    static func updateInstallments(
        for transaction: Transaction,
        newInstallments: [(sequenceNumber: Int, amount: Decimal, dueDate: Date)],
        in context: ModelContext
    ) throws {
        // Remove existing installments
        for installment in transaction.installments {
            context.delete(installment)
        }
        
        // Create new installments
        for data in newInstallments {
            let installment = Installment(
                sequenceNumber: data.sequenceNumber,
                amount: data.amount,
                dueDate: data.dueDate,
                transaction: transaction
            )
            context.insert(installment)
        }
        
        try context.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(transaction)
        }
    }
    
    /// Marks an installment as paid and creates a payment transaction
    @MainActor
    static func markInstallmentPaid(
        _ installment: Installment,
        paidDate: Date = .now,
        in context: ModelContext
    ) throws {
        guard let transaction = installment.transaction,
              let salesman = transaction.salesman else {
            // Just mark as paid without creating payment if no salesman
            installment.isPaid = true
            installment.paidDate = paidDate
            try context.save()
            return
        }
        
        // Create a payment transaction for this installment
        let paymentNote = String(localized: "Installment #\(installment.sequenceNumber) payment")
        let payment = Transaction(
            type: .payment,
            amount: -installment.amount,  // Negative to reduce balance
            salesman: salesman,
            occurredAt: paidDate,
            note: paymentNote
        )
        context.insert(payment)
        
        // Link the payment to the installment
        installment.isPaid = true
        installment.paidDate = paidDate
        installment.paymentTransaction = payment
        
        try context.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(payment)
            await SyncService.shared.push(installment)
        }
    }
    
    /// Marks an installment as unpaid and reverses its payment transaction
    @MainActor
    static func markInstallmentUnpaid(
        _ installment: Installment,
        in context: ModelContext
    ) throws {
        // If there's an associated payment transaction, reverse it
        if let paymentTransaction = installment.paymentTransaction {
            try reverse(paymentTransaction, in: context)
        }
        
        installment.isPaid = false
        installment.paidDate = nil
        installment.paymentTransaction = nil
        try context.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(installment)
        }
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
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(transaction)
        }
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
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(transaction)
        }
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
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(transaction)
        }
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
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(reversal)
            await SyncService.shared.push(original)
        }
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

// MARK: - Data Management

extension LedgerService {
    
    /// Clears all local data from SwiftData.
    /// Call this when user logs out or switches to a different business.
    @MainActor
    static func clearAllData(in context: ModelContext) {
        // Delete in order to respect relationships
        // First delete items that reference other entities
        try? context.delete(model: TransactionItem.self)
        try? context.delete(model: Installment.self)
        try? context.delete(model: Transaction.self)
        try? context.delete(model: Product.self)
        try? context.delete(model: Salesman.self)
        
        try? context.save()
    }
}

// MARK: - Decimal Rounding Extension

private extension Decimal {
    func rounded(scale: Int, roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, roundingMode)
        return result
    }
}

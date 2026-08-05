import Foundation
import SwiftData

enum LedgerError: Error {
    case alreadyReversed
    case missingCustomer
    case insufficientReturnableQuantity
}

/// A batch of units distributed at a single historical unit price.
struct PriceLot {
    let unitPrice: Decimal
    var quantity: Decimal
}

enum LedgerService {
    
    // MARK: - Walk-in Customer for Quick Sales
    
    /// The special name used for anonymous walk-in customers
    static let walkInCustomerName = "Walk-in Customer"
    
    /// Gets or creates a walk-in customer for anonymous cash sales
    @MainActor
    static func getOrCreateWalkInCustomer(in context: ModelContext) -> Customer {
        let descriptor = FetchDescriptor<Customer>(
            predicate: #Predicate<Customer> { $0.name == "Walk-in Customer" && $0.deletedAt == nil }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let walkIn = Customer(name: walkInCustomerName, notes: "Anonymous cash sales")
        context.insert(walkIn)
        return walkIn
    }
    
    /// Records a quick cash sale for a walk-in customer.
    /// This creates both a distribution and an immediate payment, resulting in a net-zero balance.
    @MainActor
    static func recordQuickSale(
        items: [(product: Product, quantity: Decimal, unitPriceOverride: Decimal?)],
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let walkInCustomer = getOrCreateWalkInCustomer(in: context)
        
        // 1. Record the distribution (creates positive balance)
        // Create transaction items with custom prices if provided
        let transactionItems = items.map { item in
            if let override = item.unitPriceOverride {
                return TransactionItem(product: item.product, quantity: item.quantity, unitPriceOverride: override)
            } else {
                return TransactionItem(product: item.product, quantity: item.quantity, paymentType: .cash)
            }
        }
        
        // Calculate total from actual transaction items (respecting price overrides)
        let total = transactionItems.reduce(Decimal(0)) { sum, item in
            sum + item.lineTotal
        }
        
        let distributionTransaction = Transaction(
            type: .distribution,
            amount: total,
            customer: walkInCustomer,
            occurredAt: occurredAt,
            note: note,
            attachmentFileName: attachmentFileName,
            paymentType: .cash
        )
        context.insert(distributionTransaction)
        
        for item in transactionItems {
            item.transaction = distributionTransaction
            context.insert(item)
        }
        
        // 2. Record the payment immediately (creates negative balance, zeroing out)
        let paymentTransaction = Transaction(
            type: .payment,
            amount: -total,  // negative to reduce balance
            customer: walkInCustomer,
            occurredAt: occurredAt,
            note: note != nil ? "Payment for: \(note!)" : "Quick sale payment"
        )
        context.insert(paymentTransaction)
        
        try context.save()
        
        // Sync both transactions to Firestore
        Task {
            await SyncService.shared.push(distributionTransaction)
            await SyncService.shared.push(paymentTransaction)
        }
    }

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
        to customer: Customer,
        items: [(product: Product, quantity: Decimal, unitPriceOverride: Decimal?)],
        paymentType: PaymentType = .cash,
        installmentConfig: InstallmentConfig? = nil,
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let transactionItems = items.map { item in
            // If there's a custom price override, use it; otherwise use the payment type default
            if let override = item.unitPriceOverride {
                return TransactionItem(product: item.product, quantity: item.quantity, unitPriceOverride: override)
            } else {
                return TransactionItem(product: item.product, quantity: item.quantity, paymentType: paymentType)
            }
        }
        let total = transactionItems.reduce(Decimal(0)) { $0 + $1.lineTotal }

        let transaction = Transaction(
            type: .distribution,
            amount: total,
            customer: customer,
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
              let customer = transaction.customer else {
            // Just mark as paid without creating payment if no customer
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
            customer: customer,
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
        items: [(product: Product, quantity: Decimal)],
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
            sum + (item.quantity * (item.product?.costPrice ?? 0))
        }

        let transaction = Transaction(
            type: .stockReceipt,
            amount: total,
            customer: nil,
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
        from customer: Customer,
        amount: Decimal,
        note: String? = nil,
        attachmentFileName: String? = nil,
        occurredAt: Date = .now,
        in context: ModelContext
    ) throws {
        let transaction = Transaction(
            type: .payment,
            amount: -amount,  // stored as negative to reduce balance
            customer: customer,
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
        from customer: Customer,
        items: [(product: Product, quantity: Decimal)],
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
            let lots = outstandingLots(for: customer, product: product)
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

        // Amount is negative because it reduces what customer owes
        let transaction = Transaction(
            type: .return,
            amount: -total,
            customer: customer,
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

        guard let customer = original.customer else {
            throw LedgerError.missingCustomer
        }

        let reversal = Transaction(
            type: .adjustment,
            amount: -original.amount,
            customer: customer,
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

    /// Units of a product still in the customer's hands, grouped by the unit price
    /// they were distributed at, oldest first. Prior returns consume lots FIFO.
    static func outstandingLots(for customer: Customer, product: Product) -> [PriceLot] {
        let activeTransactions = customer.transactions
            .filter { $0.reversedBy == nil }
            .sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.createdAt < $1.createdAt
            }

        var lots: [PriceLot] = []
        var returnedQuantity: Decimal = 0

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
    static func value(of quantity: Decimal, from lots: [PriceLot]) -> Decimal {
        guard let segments = try? consume(quantity, from: lots) else {
            return Decimal(0)
        }
        return segments.reduce(Decimal(0)) { $0 + $1.quantity * $1.unitPrice }
    }

    /// Splits `quantity` across lots FIFO, returning one segment per price consumed.
    private static func consume(_ quantity: Decimal, from lots: [PriceLot]) throws -> [PriceLot] {
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
    private static func consumed(_ lots: [PriceLot], by quantity: Decimal) -> [PriceLot] {
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
    /// Uses individual object deletion instead of batch delete to handle relationship constraints.
    @MainActor
    static func clearAllData(in context: ModelContext) {
        // Fetch and delete individually to handle relationship constraints properly
        // Delete in order: most dependent entities first
        
        // 1. Delete TransactionItems first (depends on Product and Transaction)
        let itemDescriptor = FetchDescriptor<TransactionItem>()
        if let items = try? context.fetch(itemDescriptor) {
            for item in items {
                context.delete(item)
            }
        }
        
        // 2. Delete Installments (depends on Transaction)
        let installmentDescriptor = FetchDescriptor<Installment>()
        if let installments = try? context.fetch(installmentDescriptor) {
            for installment in installments {
                context.delete(installment)
            }
        }
        
        // 3. Delete Transactions (depends on Customer)
        let transactionDescriptor = FetchDescriptor<Transaction>()
        if let transactions = try? context.fetch(transactionDescriptor) {
            for transaction in transactions {
                context.delete(transaction)
            }
        }
        
        // 4. Delete Products (no dependencies after items are deleted)
        let productDescriptor = FetchDescriptor<Product>()
        if let products = try? context.fetch(productDescriptor) {
            for product in products {
                context.delete(product)
            }
        }
        
        // 5. Delete Customers last (was referenced by transactions)
        let customerDescriptor = FetchDescriptor<Customer>()
        if let customers = try? context.fetch(customerDescriptor) {
            for customer in customers {
                context.delete(customer)
            }
        }
        
        // Save all deletions
        try? context.save()
    }
}

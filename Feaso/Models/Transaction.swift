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
    
    /// Payment type for distributions (cash or installment). Nil for non-distribution transactions.
    var paymentTypeRaw: String?
    
    var customer: Customer?
    
    @Relationship(deleteRule: .cascade, inverse: \TransactionItem.transaction)
    var items: [TransactionItem] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Installment.transaction)
    var installments: [Installment] = []
    
    var reversedBy: Transaction?
    var reverses: Transaction?
    
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .adjustment }
        set { typeRaw = newValue.rawValue }
    }
    
    var paymentType: PaymentType? {
        get { paymentTypeRaw.flatMap { PaymentType(rawValue: $0) } }
        set { paymentTypeRaw = newValue?.rawValue }
    }
    
    init(
        type: TransactionType,
        amount: Decimal,
        customer: Customer? = nil,
        occurredAt: Date = .now,
        note: String? = nil,
        attachmentFileName: String? = nil,
        paymentType: PaymentType? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.customer = customer
        self.occurredAt = occurredAt
        self.note = note
        self.attachmentFileName = attachmentFileName
        self.paymentTypeRaw = paymentType?.rawValue
        self.createdAt = .now
    }
    
    var isReversed: Bool { reversedBy != nil }
    var isReversal: Bool { reverses != nil }
    var hasAttachment: Bool { attachmentFileName != nil }
    
    // MARK: - Installment Helpers
    
    var hasInstallments: Bool {
        !installments.isEmpty
    }
    
    var sortedInstallments: [Installment] {
        installments.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }
    
    var totalInstallmentAmount: Decimal {
        installments.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    var paidInstallmentAmount: Decimal {
        installments.filter { $0.isPaid }.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    var remainingInstallmentAmount: Decimal {
        totalInstallmentAmount - paidInstallmentAmount
    }
    
    var paidInstallmentsCount: Int {
        installments.filter { $0.isPaid }.count
    }
    
    var nextDueInstallment: Installment? {
        sortedInstallments.first { !$0.isPaid }
    }
    
    var overdueInstallments: [Installment] {
        installments.filter { $0.isOverdue }
    }
    
    var hasOverdueInstallments: Bool {
        installments.contains { $0.isOverdue }
    }
}

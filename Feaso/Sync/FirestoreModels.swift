import Foundation
import FirebaseFirestore

// MARK: - Firestore DTOs
// These models are used for Firestore serialization.
// They mirror SwiftData models but use Firestore-compatible types.
// Decimal is stored as String to avoid floating point errors.

// MARK: - Firestore Salesman

struct FirestoreSalesman: Codable {
    let id: String
    var name: String
    var phone: String?
    var notes: String?
    var createdAt: Timestamp
    var deletedAt: Timestamp?
    var updatedAt: Timestamp
    
    init(from salesman: Salesman) {
        self.id = salesman.id.uuidString
        self.name = salesman.name
        self.phone = salesman.phone
        self.notes = salesman.notes
        self.createdAt = Timestamp(date: salesman.createdAt)
        self.deletedAt = salesman.deletedAt.map { Timestamp(date: $0) }
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toSalesman() -> Salesman {
        let salesman = Salesman(name: name, phone: phone, notes: notes)
        // Overwrite auto-generated values
        salesman.id = UUID(uuidString: id) ?? UUID()
        salesman.createdAt = createdAt.dateValue()
        salesman.deletedAt = deletedAt?.dateValue()
        return salesman
    }
    
    func update(_ salesman: Salesman) {
        salesman.name = name
        salesman.phone = phone
        salesman.notes = notes
        salesman.deletedAt = deletedAt?.dateValue()
    }
}

// MARK: - Firestore Product

struct FirestoreProduct: Codable {
    let id: String
    var name: String
    var costPrice: String
    var cashPrice: String
    var installmentPrice: String
    var openingStock: Int
    var reorderThreshold: Int?
    var createdAt: Timestamp
    var deletedAt: Timestamp?
    var updatedAt: Timestamp
    
    init(from product: Product) {
        self.id = product.id.uuidString
        self.name = product.name
        self.costPrice = "\(product.costPrice)"
        self.cashPrice = "\(product.cashPrice)"
        self.installmentPrice = "\(product.installmentPrice)"
        self.openingStock = product.openingStock
        self.reorderThreshold = product.reorderThreshold
        self.createdAt = Timestamp(date: product.createdAt)
        self.deletedAt = product.deletedAt.map { Timestamp(date: $0) }
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toProduct() -> Product {
        let product = Product(
            name: name,
            costPrice: Decimal(string: costPrice) ?? 0,
            cashPrice: Decimal(string: cashPrice) ?? 0,
            installmentPrice: Decimal(string: installmentPrice),
            openingStock: openingStock,
            reorderThreshold: reorderThreshold
        )
        product.id = UUID(uuidString: id) ?? UUID()
        product.createdAt = createdAt.dateValue()
        product.deletedAt = deletedAt?.dateValue()
        return product
    }
    
    func update(_ product: Product) {
        product.name = name
        product.costPrice = Decimal(string: costPrice) ?? product.costPrice
        product.cashPrice = Decimal(string: cashPrice) ?? product.cashPrice
        product.installmentPrice = Decimal(string: installmentPrice) ?? product.installmentPrice
        product.openingStock = openingStock
        product.reorderThreshold = reorderThreshold
        product.deletedAt = deletedAt?.dateValue()
    }
}

// MARK: - Firestore Transaction

struct FirestoreTransaction: Codable {
    let id: String
    var typeRaw: String
    var amount: String
    var occurredAt: Timestamp
    var note: String?
    var createdAt: Timestamp
    var attachmentFileName: String?
    var paymentTypeRaw: String?
    var salesmanId: String?
    var reversedById: String?
    var reversesId: String?
    var updatedAt: Timestamp
    
    init(from transaction: Transaction) {
        self.id = transaction.id.uuidString
        self.typeRaw = transaction.typeRaw
        self.amount = "\(transaction.amount)"
        self.occurredAt = Timestamp(date: transaction.occurredAt)
        self.note = transaction.note
        self.createdAt = Timestamp(date: transaction.createdAt)
        self.attachmentFileName = transaction.attachmentFileName
        self.paymentTypeRaw = transaction.paymentTypeRaw
        self.salesmanId = transaction.salesman?.id.uuidString
        self.reversedById = transaction.reversedBy?.id.uuidString
        self.reversesId = transaction.reverses?.id.uuidString
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toTransaction() -> Transaction {
        let transactionType = TransactionType(rawValue: typeRaw) ?? .adjustment
        let paymentType = paymentTypeRaw.flatMap { PaymentType(rawValue: $0) }
        
        let transaction = Transaction(
            type: transactionType,
            amount: Decimal(string: amount) ?? 0,
            salesman: nil, // Set separately
            occurredAt: occurredAt.dateValue(),
            note: note,
            attachmentFileName: attachmentFileName,
            paymentType: paymentType
        )
        transaction.id = UUID(uuidString: id) ?? UUID()
        transaction.createdAt = createdAt.dateValue()
        // Relationships (salesman, items, installments) are set separately
        return transaction
    }
}

// MARK: - Firestore Transaction Item

struct FirestoreTransactionItem: Codable {
    let id: String
    var quantity: Int
    var unitPrice: String
    var transactionId: String
    var productId: String
    var updatedAt: Timestamp
    
    init(from item: TransactionItem, transactionId: UUID) {
        self.id = item.id.uuidString
        self.quantity = item.quantity
        self.unitPrice = "\(item.unitPrice)"
        self.transactionId = transactionId.uuidString
        self.productId = item.product?.id.uuidString ?? ""
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toTransactionItem(product: Product) -> TransactionItem {
        let item = TransactionItem(
            product: product,
            quantity: quantity,
            unitPriceOverride: Decimal(string: unitPrice) ?? 0
        )
        item.id = UUID(uuidString: id) ?? UUID()
        return item
    }
}

// MARK: - Firestore Installment

struct FirestoreInstallment: Codable {
    let id: String
    var sequenceNumber: Int
    var amount: String
    var dueDate: Timestamp
    var isPaid: Bool
    var paidDate: Timestamp?
    var note: String?
    var createdAt: Timestamp
    var transactionId: String
    var paymentTransactionId: String?
    var updatedAt: Timestamp
    
    init(from installment: Installment) {
        self.id = installment.id.uuidString
        self.sequenceNumber = installment.sequenceNumber
        self.amount = "\(installment.amount)"
        self.dueDate = Timestamp(date: installment.dueDate)
        self.isPaid = installment.isPaid
        self.paidDate = installment.paidDate.map { Timestamp(date: $0) }
        self.note = installment.note
        self.createdAt = Timestamp(date: installment.createdAt)
        self.transactionId = installment.transaction?.id.uuidString ?? ""
        self.paymentTransactionId = installment.paymentTransaction?.id.uuidString
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toInstallment() -> Installment {
        let installment = Installment(
            sequenceNumber: sequenceNumber,
            amount: Decimal(string: amount) ?? 0,
            dueDate: dueDate.dateValue()
        )
        installment.id = UUID(uuidString: id) ?? UUID()
        installment.isPaid = isPaid
        installment.paidDate = paidDate?.dateValue()
        installment.note = note
        installment.createdAt = createdAt.dateValue()
        // Transaction relationship is set separately
        return installment
    }
    
    func update(_ installment: Installment) {
        installment.sequenceNumber = sequenceNumber
        installment.amount = Decimal(string: amount) ?? installment.amount
        installment.dueDate = dueDate.dateValue()
        installment.isPaid = isPaid
        installment.paidDate = paidDate?.dateValue()
        installment.note = note
    }
}

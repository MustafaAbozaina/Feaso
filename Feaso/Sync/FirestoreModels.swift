import Foundation
import FirebaseFirestore

// MARK: - Firestore DTOs
// These models are used for Firestore serialization.
// They mirror SwiftData models but use Firestore-compatible types.
// Decimal is stored as String to avoid floating point errors.

// MARK: - Firestore User (for multi-user business structure)

/// Represents a user document in /users/{uid}
/// Links Firebase Auth users to their business and role.
/// The document ID itself is the user's Firebase Auth UID.
struct FirestoreUser: Codable {
    var email: String?
    var displayName: String?
    var businessId: String      // Reference to /businesses/{businessId}
    var role: String            // "owner", "admin", "employee"
    var createdAt: Timestamp?   // Optional for backward compatibility
    
    init(email: String?, displayName: String?, businessId: String, role: String) {
        self.email = email
        self.displayName = displayName
        self.businessId = businessId
        self.role = role
        self.createdAt = Timestamp(date: .now)
    }
}

// MARK: - Firestore Business

/// Represents a business document in /businesses/{businessId}
/// The document ID itself is the businessId - no need for separate id field.
struct FirestoreBusiness: Codable {
    var name: String
    var ownerId: String         // Firebase Auth UID of the owner
    var createdAt: Timestamp?   // Optional for backward compatibility
    
    init(name: String, ownerId: String) {
        self.name = name
        self.ownerId = ownerId
        self.createdAt = Timestamp(date: .now)
    }
}

// MARK: - Firestore Customer

struct FirestoreCustomer: Codable {
    let id: String
    var name: String
    var phone: String?
    var notes: String?
    var createdAt: Timestamp
    var deletedAt: Timestamp?
    var updatedAt: Timestamp
    
    init(from customer: Customer) {
        self.id = customer.id.uuidString
        self.name = customer.name
        self.phone = customer.phone
        self.notes = customer.notes
        self.createdAt = Timestamp(date: customer.createdAt)
        self.deletedAt = customer.deletedAt.map { Timestamp(date: $0) }
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toCustomer() -> Customer {
        let customer = Customer(name: name, phone: phone, notes: notes)
        // Overwrite auto-generated values
        customer.id = UUID(uuidString: id) ?? UUID()
        customer.createdAt = createdAt.dateValue()
        customer.deletedAt = deletedAt?.dateValue()
        return customer
    }
    
    func update(_ customer: Customer) {
        customer.name = name
        customer.phone = phone
        customer.notes = notes
        customer.deletedAt = deletedAt?.dateValue()
    }
}

// MARK: - Firestore Product

struct FirestoreProduct: Codable {
    let id: String
    var name: String
    var costPrice: String
    var cashPrice: String
    var installmentPrice: String
    var openingStock: String
    var reorderThreshold: String?
    var unitRaw: String?
    var createdAt: Timestamp
    var deletedAt: Timestamp?
    var updatedAt: Timestamp
    
    init(from product: Product) {
        self.id = product.id.uuidString
        self.name = product.name
        self.costPrice = "\(product.costPrice)"
        self.cashPrice = "\(product.cashPrice)"
        self.installmentPrice = "\(product.installmentPrice)"
        self.openingStock = "\(product.openingStock)"
        self.reorderThreshold = product.reorderThreshold.map { "\($0)" }
        self.unitRaw = product.unitRaw
        self.createdAt = Timestamp(date: product.createdAt)
        self.deletedAt = product.deletedAt.map { Timestamp(date: $0) }
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toProduct() -> Product {
        let unit = unitRaw.flatMap { ProductUnit(rawValue: $0) } ?? .piece
        let product = Product(
            name: name,
            costPrice: Decimal(string: costPrice) ?? 0,
            cashPrice: Decimal(string: cashPrice) ?? 0,
            installmentPrice: Decimal(string: installmentPrice),
            openingStock: Decimal(string: openingStock) ?? 0,
            reorderThreshold: reorderThreshold.flatMap { Decimal(string: $0) },
            unit: unit
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
        product.openingStock = Decimal(string: openingStock) ?? product.openingStock
        product.reorderThreshold = reorderThreshold.flatMap { Decimal(string: $0) }
        // Note: unit is NOT updated - it's immutable after creation
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
    var createdAt: Timestamp?        // Optional for backward compatibility
    var attachmentFileName: String?
    var paymentTypeRaw: String?
    var customerId: String?
    var reversedById: String?
    var reversesId: String?
    var updatedAt: Timestamp?        // Optional for backward compatibility
    
    init(from transaction: Transaction) {
        self.id = transaction.id.uuidString
        self.typeRaw = transaction.typeRaw
        self.amount = "\(transaction.amount)"
        self.occurredAt = Timestamp(date: transaction.occurredAt)
        self.note = transaction.note
        self.createdAt = Timestamp(date: transaction.createdAt)
        self.attachmentFileName = transaction.attachmentFileName
        self.paymentTypeRaw = transaction.paymentTypeRaw
        self.customerId = transaction.customer?.id.uuidString
        self.reversedById = transaction.reversedBy?.id.uuidString
        self.reversesId = transaction.reverses?.id.uuidString
        self.updatedAt = Timestamp(date: .now)
    }
    
    /// Direct initializer that accepts pre-resolved values for background contexts
    init(
        id: String,
        typeRaw: String,
        amount: String,
        occurredAt: Date,
        note: String?,
        createdAt: Date,
        attachmentFileName: String?,
        paymentTypeRaw: String?,
        customerId: String?,
        reversedById: String?,
        reversesId: String?
    ) {
        self.id = id
        self.typeRaw = typeRaw
        self.amount = amount
        self.occurredAt = Timestamp(date: occurredAt)
        self.note = note
        self.createdAt = Timestamp(date: createdAt)
        self.attachmentFileName = attachmentFileName
        self.paymentTypeRaw = paymentTypeRaw
        self.customerId = customerId
        self.reversedById = reversedById
        self.reversesId = reversesId
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toTransaction() -> Transaction {
        let transactionType = TransactionType(rawValue: typeRaw) ?? .adjustment
        let paymentType = paymentTypeRaw.flatMap { PaymentType(rawValue: $0) }
        
        let transaction = Transaction(
            type: transactionType,
            amount: Decimal(string: amount) ?? 0,
            customer: nil, // Set separately
            occurredAt: occurredAt.dateValue(),
            note: note,
            attachmentFileName: attachmentFileName,
            paymentType: paymentType
        )
        transaction.id = UUID(uuidString: id) ?? UUID()
        transaction.createdAt = createdAt?.dateValue() ?? Date()
        // Relationships (customer, items, installments) are set separately
        return transaction
    }
}

// MARK: - Firestore Transaction Item

struct FirestoreTransactionItem: Codable {
    let id: String
    var quantity: String
    var unitPrice: String
    var transactionId: String
    var productId: String
    var updatedAt: Timestamp?       // Optional for backward compatibility
    
    init(from item: TransactionItem, transactionId: UUID) {
        self.id = item.id.uuidString
        self.quantity = "\(item.quantity)"
        self.unitPrice = "\(item.unitPrice)"
        self.transactionId = transactionId.uuidString
        self.productId = item.product?.id.uuidString ?? ""
        self.updatedAt = Timestamp(date: .now)
    }
    
    /// Direct initializer for when we have raw values
    init(id: String, quantity: String, unitPrice: String, transactionId: String, productId: String) {
        self.id = id
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.transactionId = transactionId
        self.productId = productId
        self.updatedAt = Timestamp(date: .now)
    }
    
    func toTransactionItem(product: Product) -> TransactionItem {
        let item = TransactionItem(
            product: product,
            quantity: Decimal(string: quantity) ?? 0,
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
    var createdAt: Timestamp?       // Optional for backward compatibility
    var transactionId: String
    var paymentTransactionId: String?
    var updatedAt: Timestamp?       // Optional for backward compatibility
    
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
    
    /// Direct initializer that accepts pre-resolved values for background contexts
    init(
        id: String,
        sequenceNumber: Int,
        amount: String,
        dueDate: Date,
        isPaid: Bool,
        paidDate: Date?,
        note: String?,
        createdAt: Date,
        transactionId: String,
        paymentTransactionId: String?
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.amount = amount
        self.dueDate = Timestamp(date: dueDate)
        self.isPaid = isPaid
        self.paidDate = paidDate.map { Timestamp(date: $0) }
        self.note = note
        self.createdAt = Timestamp(date: createdAt)
        self.transactionId = transactionId
        self.paymentTransactionId = paymentTransactionId
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
        installment.createdAt = createdAt?.dateValue() ?? Date()
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

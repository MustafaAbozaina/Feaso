import Foundation
import FirebaseFirestore
import SwiftData
import Observation

// MARK: - Firebase Pull Sync Provider Implementation

/// Firebase/Firestore implementation of SyncProvider protocol using pull-on-demand.
/// This is a cost-effective approach that only fetches data when explicitly requested
/// (on app launch, foreground, or manual refresh) rather than using real-time listeners.
@Observable
final class FirebasePullSyncProvider: SyncProvider {
    
    // MARK: - Singleton
    
    static let shared = FirebasePullSyncProvider()
    
    // MARK: - State
    
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    
    // MARK: - Private
    
    private let db: Firestore
    private var modelContext: ModelContext?
    
    // MARK: - Init
    
    private init() {
        db = Firestore.firestore()
        
        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }
    
    // MARK: - Collection References
    
    private var businessId: String? {
        AuthService.shared.businessId
    }
    
    private func businessCollection(_ name: String) -> CollectionReference? {
        guard let businessId else { return nil }
        return db.collection("businesses").document(businessId).collection(name)
    }
    
    // MARK: - SyncProvider Protocol
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    func startSync() {
        guard businessId != nil else {
            syncError = SyncError.noBusinessId
            return
        }
        
        syncError = nil
        performInitialSync()
    }
    
    func stopSync() {
        // No listeners to stop in pull-based sync
    }
    
    /// Manually trigger a pull from the server.
    /// Call this on foreground, pull-to-refresh, or manual sync button.
    func refreshFromServer() async {
        guard businessId != nil else {
            syncError = SyncError.noBusinessId
            return
        }
        
        do {
            try await pullAllData()
            syncError = nil
        } catch {
            syncError = error
        }
    }
    
    // MARK: - Push Operations
    
    func push(_ customer: Customer) async throws {
        guard let collection = businessCollection("customers") else {
            throw SyncError.noBusinessId
        }
        
        let firestoreModel = FirestoreCustomer(from: customer)
        try collection.document(customer.id.uuidString).setData(from: firestoreModel)
    }
    
    func push(_ product: Product) async throws {
        guard let collection = businessCollection("products") else {
            throw SyncError.noBusinessId
        }
        
        let firestoreModel = FirestoreProduct(from: product)
        try collection.document(product.id.uuidString).setData(from: firestoreModel)
    }
    
    func push(_ transaction: Transaction) async throws {
        guard let transactionsCollection = businessCollection("transactions"),
              let itemsCollection = businessCollection("transactionItems"),
              let installmentsCollection = businessCollection("installments") else {
            throw SyncError.noBusinessId
        }
        
        // Capture ALL data on main actor to ensure relationships are resolved
        let transactionData = await MainActor.run {
            (
                id: transaction.id,
                typeRaw: transaction.typeRaw,
                amount: transaction.amount,
                occurredAt: transaction.occurredAt,
                note: transaction.note,
                createdAt: transaction.createdAt,
                attachmentFileName: transaction.attachmentFileName,
                paymentTypeRaw: transaction.paymentTypeRaw,
                customerId: transaction.customer?.id.uuidString,
                reversedById: transaction.reversedBy?.id.uuidString,
                reversesId: transaction.reverses?.id.uuidString,
                recordedByUserId: transaction.recordedByUserId,
                recordedByName: transaction.recordedByName,
                recordedByEmail: transaction.recordedByEmail,
                items: transaction.items.map { item in
                    (id: item.id, productId: item.product?.id.uuidString ?? "", quantity: item.quantity, unitPrice: item.unitPrice)
                },
                installments: transaction.installments.map { inst in
                    (id: inst.id, sequenceNumber: inst.sequenceNumber, amount: inst.amount, dueDate: inst.dueDate,
                     isPaid: inst.isPaid, paidDate: inst.paidDate, note: inst.note, createdAt: inst.createdAt,
                     paymentTransactionId: inst.paymentTransaction?.id.uuidString)
                }
            )
        }
        
        // Build Firestore transaction model from captured data
        let firestoreTransaction = FirestoreTransaction(
            id: transactionData.id.uuidString,
            typeRaw: transactionData.typeRaw,
            amount: "\(transactionData.amount)",
            occurredAt: transactionData.occurredAt,
            note: transactionData.note,
            createdAt: transactionData.createdAt,
            attachmentFileName: transactionData.attachmentFileName,
            paymentTypeRaw: transactionData.paymentTypeRaw,
            customerId: transactionData.customerId,
            reversedById: transactionData.reversedById,
            reversesId: transactionData.reversesId,
            recordedByUserId: transactionData.recordedByUserId,
            recordedByName: transactionData.recordedByName,
            recordedByEmail: transactionData.recordedByEmail
        )
        
        // Push transaction
        try transactionsCollection.document(transactionData.id.uuidString)
            .setData(from: firestoreTransaction)
        
        // Push associated items
        for item in transactionData.items {
            let firestoreItem = FirestoreTransactionItem(
                id: item.id.uuidString,
                quantity: "\(item.quantity)",
                unitPrice: "\(item.unitPrice)",
                transactionId: transactionData.id.uuidString,
                productId: item.productId
            )
            try itemsCollection.document(item.id.uuidString)
                .setData(from: firestoreItem)
        }
        
        // Push associated installments
        for inst in transactionData.installments {
            let firestoreInstallment = FirestoreInstallment(
                id: inst.id.uuidString,
                sequenceNumber: inst.sequenceNumber,
                amount: "\(inst.amount)",
                dueDate: inst.dueDate,
                isPaid: inst.isPaid,
                paidDate: inst.paidDate,
                note: inst.note,
                createdAt: inst.createdAt,
                transactionId: transactionData.id.uuidString,
                paymentTransactionId: inst.paymentTransactionId
            )
            try installmentsCollection.document(inst.id.uuidString)
                .setData(from: firestoreInstallment)
        }
    }
    
    func push(_ installment: Installment) async throws {
        guard let collection = businessCollection("installments") else {
            throw SyncError.noBusinessId
        }
        
        let firestoreModel = FirestoreInstallment(from: installment)
        try collection.document(installment.id.uuidString).setData(from: firestoreModel)
    }
    
    // MARK: - Pull Operations
    
    func pullAllData() async throws {
        guard let context = modelContext else { return }
        
        // Maps to track IDs for relationship reconstruction
        var customersMap: [String: Customer] = [:]
        var productsMap: [String: Product] = [:]
        var transactionsMap: [String: Transaction] = [:]
        
        // Fetch existing local IDs to avoid duplicates
        let existingCustomerIds = await getExistingIds(for: Customer.self, in: context)
        let existingProductIds = await getExistingIds(for: Product.self, in: context)
        let existingTransactionIds = await getExistingIds(for: Transaction.self, in: context)
        let existingItemIds = await getExistingIds(for: TransactionItem.self, in: context)
        let existingInstallmentIds = await getExistingIds(for: Installment.self, in: context)
        
        // Pull customers
        if let collection = businessCollection("customers") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                if let firestoreCustomer = try? doc.data(as: FirestoreCustomer.self) {
                    guard let uuid = UUID(uuidString: firestoreCustomer.id) else { continue }
                    
                    await MainActor.run {
                        if existingCustomerIds.contains(uuid) {
                            // Update existing
                            if let existing = fetchLocal(Customer.self, id: uuid, in: context) {
                                firestoreCustomer.update(existing)
                                customersMap[firestoreCustomer.id] = existing
                            }
                        } else {
                            // Insert new
                            let customer = firestoreCustomer.toCustomer()
                            context.insert(customer)
                            customersMap[firestoreCustomer.id] = customer
                        }
                    }
                }
            }
        }
        
        // Pull products
        if let collection = businessCollection("products") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                if let firestoreProduct = try? doc.data(as: FirestoreProduct.self) {
                    guard let uuid = UUID(uuidString: firestoreProduct.id) else { continue }
                    
                    await MainActor.run {
                        if existingProductIds.contains(uuid) {
                            // Update existing
                            if let existing = fetchLocal(Product.self, id: uuid, in: context) {
                                firestoreProduct.update(existing)
                                productsMap[firestoreProduct.id] = existing
                            }
                        } else {
                            // Insert new
                            let product = firestoreProduct.toProduct()
                            context.insert(product)
                            productsMap[firestoreProduct.id] = product
                        }
                    }
                }
            }
        }
        
        // Also populate maps with existing local data for relationship linking
        await MainActor.run {
            for id in existingCustomerIds {
                if let customer = fetchLocal(Customer.self, id: id, in: context) {
                    customersMap[id.uuidString] = customer
                }
            }
            for id in existingProductIds {
                if let product = fetchLocal(Product.self, id: id, in: context) {
                    productsMap[id.uuidString] = product
                }
            }
        }
        
        // Pull transactions
        if let collection = businessCollection("transactions") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                do {
                    let firestoreTransaction = try doc.data(as: FirestoreTransaction.self)
                    guard let uuid = UUID(uuidString: firestoreTransaction.id) else { continue }
                    
                    await MainActor.run {
                        if existingTransactionIds.contains(uuid) {
                            // Already exists - update customer relationship and audit trail if needed
                            if let existing = fetchLocal(Transaction.self, id: uuid, in: context) {
                                if let customerId = firestoreTransaction.customerId,
                                   let customer = customersMap[customerId],
                                   existing.customer?.id.uuidString != customerId {
                                    existing.customer = customer
                                }
                                // Update audit trail fields from Firestore
                                existing.recordedByUserId = firestoreTransaction.recordedByUserId
                                existing.recordedByName = firestoreTransaction.recordedByName
                                existing.recordedByEmail = firestoreTransaction.recordedByEmail
                                transactionsMap[firestoreTransaction.id] = existing
                            }
                        } else {
                            // Insert new
                            let transaction = firestoreTransaction.toTransaction()
                            if let customerId = firestoreTransaction.customerId,
                               let customer = customersMap[customerId] {
                                transaction.customer = customer
                            }
                            context.insert(transaction)
                            transactionsMap[firestoreTransaction.id] = transaction
                        }
                    }
                } catch {
                    // Silently skip malformed documents
                }
            }
        }
        
        // Also populate transaction map with existing
        await MainActor.run {
            for id in existingTransactionIds {
                if let transaction = fetchLocal(Transaction.self, id: id, in: context) {
                    transactionsMap[id.uuidString] = transaction
                }
            }
        }
        
        // Pull transaction items
        if let collection = businessCollection("transactionItems") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                do {
                    let firestoreItem = try doc.data(as: FirestoreTransactionItem.self)
                    guard let uuid = UUID(uuidString: firestoreItem.id) else { continue }
                    guard !existingItemIds.contains(uuid) else { continue }
                    
                    await MainActor.run {
                        guard let product = productsMap[firestoreItem.productId] else { return }
                        let item = firestoreItem.toTransactionItem(product: product)
                        
                        if let transaction = transactionsMap[firestoreItem.transactionId] {
                            item.transaction = transaction
                            transaction.items.append(item)
                        }
                        context.insert(item)
                    }
                } catch {
                    // Silently skip malformed documents
                }
            }
        }
        
        // Pull installments
        if let collection = businessCollection("installments") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                do {
                    let firestoreInstallment = try doc.data(as: FirestoreInstallment.self)
                    guard let uuid = UUID(uuidString: firestoreInstallment.id) else { continue }
                    
                    await MainActor.run {
                        if existingInstallmentIds.contains(uuid) {
                            // Update existing (e.g., isPaid changed)
                            if let existing = fetchLocal(Installment.self, id: uuid, in: context) {
                                firestoreInstallment.update(existing)
                            }
                        } else {
                            // Insert new
                            let installment = firestoreInstallment.toInstallment()
                            if let transaction = transactionsMap[firestoreInstallment.transactionId] {
                                installment.transaction = transaction
                                transaction.installments.append(installment)
                            }
                            if let paymentTxId = firestoreInstallment.paymentTransactionId,
                               let paymentTx = transactionsMap[paymentTxId] {
                                installment.paymentTransaction = paymentTx
                            }
                            context.insert(installment)
                        }
                    }
                } catch {
                    // Silently skip malformed documents
                }
            }
        }
        
        // Save and notify
        await MainActor.run {
            try? context.save()
            context.processPendingChanges()
        }
        
        lastSyncDate = .now
    }
    
    // MARK: - Initial Sync
    
    private func performInitialSync() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            do {
                // Check if local database is empty (new device)
                let hasLocal = await hasLocalData()
                
                if hasLocal {
                    // Existing device - push local changes first, then pull remote changes
                    try await pushAllLocalData()
                    try await pullAllData()
                } else {
                    // New device - pull data from cloud
                    try await pullAllData()
                }
                
                lastSyncDate = .now
                syncError = nil
            } catch {
                syncError = error
            }
        }
    }
    
    private func hasLocalData() async -> Bool {
        guard let context = modelContext else { return false }
        
        return await MainActor.run {
            let customersCount = (try? context.fetchCount(FetchDescriptor<Customer>())) ?? 0
            let productsCount = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
            return customersCount > 0 || productsCount > 0
        }
    }
    
    private func pushAllLocalData() async throws {
        guard let context = modelContext else { return }
        
        // Push all customers
        let customers = try await MainActor.run {
            try context.fetch(FetchDescriptor<Customer>())
        }
        for customer in customers {
            try await push(customer)
        }
        
        // Push all products
        let products = try await MainActor.run {
            try context.fetch(FetchDescriptor<Product>())
        }
        for product in products {
            try await push(product)
        }
        
        // Push all transactions
        let transactions = try await MainActor.run {
            try context.fetch(FetchDescriptor<Transaction>())
        }
        for transaction in transactions {
            try await push(transaction)
        }
    }
    
    // MARK: - Helpers
    
    private func getExistingIds<T: PersistentModel>(for type: T.Type, in context: ModelContext) async -> Set<UUID> where T: Identifiable, T.ID == UUID {
        await MainActor.run {
            let descriptor = FetchDescriptor<T>()
            let items = (try? context.fetch(descriptor)) ?? []
            return Set(items.map { $0.id })
        }
    }
    
    @MainActor
    private func fetchLocal<T: PersistentModel>(_ type: T.Type, id: UUID, in context: ModelContext) -> T? where T: Identifiable, T.ID == UUID {
        let descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

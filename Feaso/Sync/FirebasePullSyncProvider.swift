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
    
    func push(_ salesman: Salesman) async throws {
        guard let collection = businessCollection("salesmen") else {
            throw SyncError.noBusinessId
        }
        
        let firestoreModel = FirestoreSalesman(from: salesman)
        try collection.document(salesman.id.uuidString).setData(from: firestoreModel)
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
        
        // Push transaction
        let firestoreTransaction = FirestoreTransaction(from: transaction)
        try transactionsCollection.document(transaction.id.uuidString)
            .setData(from: firestoreTransaction)
        
        // Push associated items
        for item in transaction.items {
            let firestoreItem = FirestoreTransactionItem(from: item, transactionId: transaction.id)
            try itemsCollection.document(item.id.uuidString)
                .setData(from: firestoreItem)
        }
        
        // Push associated installments
        for installment in transaction.installments {
            let firestoreInstallment = FirestoreInstallment(from: installment)
            try installmentsCollection.document(installment.id.uuidString)
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
        var salesmenMap: [String: Salesman] = [:]
        var productsMap: [String: Product] = [:]
        var transactionsMap: [String: Transaction] = [:]
        
        // Fetch existing local IDs to avoid duplicates
        let existingSalesmenIds = await getExistingIds(for: Salesman.self, in: context)
        let existingProductIds = await getExistingIds(for: Product.self, in: context)
        let existingTransactionIds = await getExistingIds(for: Transaction.self, in: context)
        let existingItemIds = await getExistingIds(for: TransactionItem.self, in: context)
        let existingInstallmentIds = await getExistingIds(for: Installment.self, in: context)
        
        // Pull salesmen
        if let collection = businessCollection("salesmen") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                if let firestoreSalesman = try? doc.data(as: FirestoreSalesman.self) {
                    guard let uuid = UUID(uuidString: firestoreSalesman.id) else { continue }
                    
                    await MainActor.run {
                        if existingSalesmenIds.contains(uuid) {
                            // Update existing
                            if let existing = fetchLocal(Salesman.self, id: uuid, in: context) {
                                firestoreSalesman.update(existing)
                                salesmenMap[firestoreSalesman.id] = existing
                            }
                        } else {
                            // Insert new
                            let salesman = firestoreSalesman.toSalesman()
                            context.insert(salesman)
                            salesmenMap[firestoreSalesman.id] = salesman
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
            for id in existingSalesmenIds {
                if let salesman = fetchLocal(Salesman.self, id: id, in: context) {
                    salesmenMap[id.uuidString] = salesman
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
                if let firestoreTransaction = try? doc.data(as: FirestoreTransaction.self) {
                    guard let uuid = UUID(uuidString: firestoreTransaction.id) else { continue }
                    
                    await MainActor.run {
                        if existingTransactionIds.contains(uuid) {
                            // Already exists, just add to map
                            if let existing = fetchLocal(Transaction.self, id: uuid, in: context) {
                                transactionsMap[firestoreTransaction.id] = existing
                            }
                        } else {
                            // Insert new
                            let transaction = firestoreTransaction.toTransaction()
                            // Link salesman if exists
                            if let salesmanId = firestoreTransaction.salesmanId,
                               let salesman = salesmenMap[salesmanId] {
                                transaction.salesman = salesman
                            }
                            context.insert(transaction)
                            transactionsMap[firestoreTransaction.id] = transaction
                        }
                    }
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
                if let firestoreItem = try? doc.data(as: FirestoreTransactionItem.self) {
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
                }
            }
        }
        
        // Pull installments
        if let collection = businessCollection("installments") {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                if let firestoreInstallment = try? doc.data(as: FirestoreInstallment.self) {
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
            let salesmenCount = (try? context.fetchCount(FetchDescriptor<Salesman>())) ?? 0
            let productsCount = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
            return salesmenCount > 0 || productsCount > 0
        }
    }
    
    private func pushAllLocalData() async throws {
        guard let context = modelContext else { return }
        
        // Push all salesmen
        let salesmen = try await MainActor.run {
            try context.fetch(FetchDescriptor<Salesman>())
        }
        for salesman in salesmen {
            try await push(salesman)
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

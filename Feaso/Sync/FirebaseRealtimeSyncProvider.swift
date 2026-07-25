import Foundation
import FirebaseFirestore
import SwiftData
import Observation

// MARK: - Firebase Realtime Sync Provider Implementation

/// Firebase/Firestore implementation of SyncProvider protocol using real-time listeners.
/// Handles bidirectional sync between SwiftData and Firestore with instant updates.
/// Note: This uses Firestore listeners which may incur more reads. Consider using
/// FirebasePullSyncProvider for a more cost-effective pull-on-demand approach.
@Observable
final class FirebaseRealtimeSyncProvider: SyncProvider {
    
    // MARK: - Singleton
    
    static let shared = FirebaseRealtimeSyncProvider()
    
    // MARK: - State
    
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    
    // MARK: - Private
    
    private let db: Firestore
    private var modelContext: ModelContext?
    private var listeners: [ListenerRegistration] = []
    
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
        print("🔄 [SYNC] startSync() called")
        print("🔄 [SYNC] businessId: \(businessId ?? "nil")")
        
        guard businessId != nil else {
            print("❌ [SYNC] No businessId - aborting sync")
            syncError = SyncError.noBusinessId
            return
        }
        
        syncError = nil
        print("🔄 [SYNC] Performing initial sync...")
        performInitialSync()
        // Note: Listeners are set up AFTER initial sync completes to avoid duplicates
    }
    
    func stopSync() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
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
    
    func pullAllData() async throws {
        print("📥 [PULL] pullAllData() started")
        guard let context = modelContext else {
            print("❌ [PULL] No modelContext!")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Maps to track IDs for relationship reconstruction
        var salesmenMap: [String: Salesman] = [:]
        var productsMap: [String: Product] = [:]
        var transactionsMap: [String: Transaction] = [:]
        
        // Pull salesmen first
        print("📥 [PULL] Fetching salesmen...")
        if let collection = businessCollection("salesmen") {
            let snapshot = try await collection.getDocuments()
            print("📥 [PULL] Found \(snapshot.documents.count) salesmen documents")
            for doc in snapshot.documents {
                if let firestoreSalesman = try? doc.data(as: FirestoreSalesman.self) {
                    await MainActor.run {
                        let salesman = firestoreSalesman.toSalesman()
                        context.insert(salesman)
                        salesmenMap[firestoreSalesman.id] = salesman
                        print("📥 [PULL] Inserted salesman: \(salesman.name)")
                    }
                } else {
                    print("⚠️ [PULL] Failed to decode salesman doc: \(doc.documentID)")
                }
            }
        } else {
            print("⚠️ [PULL] No salesmen collection (businessId issue?)")
        }
        
        // Pull products
        print("📥 [PULL] Fetching products...")
        if let collection = businessCollection("products") {
            let snapshot = try await collection.getDocuments()
            print("📥 [PULL] Found \(snapshot.documents.count) product documents")
            for doc in snapshot.documents {
                if let firestoreProduct = try? doc.data(as: FirestoreProduct.self) {
                    await MainActor.run {
                        let product = firestoreProduct.toProduct()
                        context.insert(product)
                        productsMap[firestoreProduct.id] = product
                        print("📥 [PULL] Inserted product: \(product.name)")
                    }
                } else {
                    print("⚠️ [PULL] Failed to decode product doc: \(doc.documentID)")
                }
            }
        } else {
            print("⚠️ [PULL] No products collection (businessId issue?)")
        }
        
        // Pull transactions
        print("📥 [PULL] Fetching transactions...")
        if let collection = businessCollection("transactions") {
            let snapshot = try await collection.getDocuments()
            print("📥 [PULL] Found \(snapshot.documents.count) transaction documents")
            for doc in snapshot.documents {
                if let firestoreTransaction = try? doc.data(as: FirestoreTransaction.self) {
                    await MainActor.run {
                        let transaction = firestoreTransaction.toTransaction()
                        // Link salesman if exists
                        if let salesmanId = firestoreTransaction.salesmanId,
                           let salesman = salesmenMap[salesmanId] {
                            transaction.salesman = salesman
                        }
                        context.insert(transaction)
                        transactionsMap[firestoreTransaction.id] = transaction
                        print("📥 [PULL] Inserted transaction: \(firestoreTransaction.id)")
                    }
                } else {
                    print("⚠️ [PULL] Failed to decode transaction doc: \(doc.documentID)")
                }
            }
        }
        
        // Pull transaction items and link to transactions and products
        print("📥 [PULL] Fetching transaction items...")
        if let collection = businessCollection("transactionItems") {
            let snapshot = try await collection.getDocuments()
            print("📥 [PULL] Found \(snapshot.documents.count) transaction item documents")
            for doc in snapshot.documents {
                if let firestoreItem = try? doc.data(as: FirestoreTransactionItem.self) {
                    await MainActor.run {
                        // Must have a product to create item
                        guard let product = productsMap[firestoreItem.productId] else {
                            print("⚠️ [PULL] No product found for item: \(firestoreItem.productId)")
                            return
                        }
                        let item = firestoreItem.toTransactionItem(product: product)
                        // Link to transaction
                        if let transaction = transactionsMap[firestoreItem.transactionId] {
                            item.transaction = transaction
                            transaction.items.append(item)
                        }
                        context.insert(item)
                    }
                }
            }
        }
        
        // Pull installments and link to transactions
        print("📥 [PULL] Fetching installments...")
        if let collection = businessCollection("installments") {
            let snapshot = try await collection.getDocuments()
            print("📥 [PULL] Found \(snapshot.documents.count) installment documents")
            for doc in snapshot.documents {
                if let firestoreInstallment = try? doc.data(as: FirestoreInstallment.self) {
                    await MainActor.run {
                        let installment = firestoreInstallment.toInstallment()
                        // Link to transaction
                        if let transaction = transactionsMap[firestoreInstallment.transactionId] {
                            installment.transaction = transaction
                            transaction.installments.append(installment)
                        }
                        // Link payment transaction if exists
                        if let paymentTxId = firestoreInstallment.paymentTransactionId,
                           let paymentTx = transactionsMap[paymentTxId] {
                            installment.paymentTransaction = paymentTx
                        }
                        context.insert(installment)
                    }
                }
            }
        }
        
        await MainActor.run {
            do {
                try context.save()
                print("✅ [PULL] Context saved successfully")
            } catch {
                print("❌ [PULL] Failed to save context: \(error)")
            }
        }
        
        print("✅ [PULL] pullAllData() completed - Salesmen: \(salesmenMap.count), Products: \(productsMap.count), Transactions: \(transactionsMap.count)")
        lastSyncDate = .now
    }
    
    // MARK: - Listeners (Pull)
    
    private func setupListeners() {
        listenToSalesmen()
        listenToProducts()
        listenToTransactions()
        listenToTransactionItems()
        listenToInstallments()
    }
    
    private func listenToSalesmen() {
        guard let collection = businessCollection("salesmen") else { return }
        
        let listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges, error == nil else {
                self?.syncError = error
                return
            }
            
            Task { @MainActor in
                for change in changes {
                    self?.handleSalesmanChange(change)
                }
            }
        }
        listeners.append(listener)
    }
    
    @MainActor
    private func handleSalesmanChange(_ change: DocumentChange) {
        guard let context = modelContext else { return }
        
        do {
            let firestoreSalesman = try change.document.data(as: FirestoreSalesman.self)
            guard let uuid = UUID(uuidString: firestoreSalesman.id) else { return }
            
            // Check if exists locally
            let descriptor = FetchDescriptor<Salesman>(
                predicate: #Predicate { $0.id == uuid }
            )
            let existing = try context.fetch(descriptor).first
            
            switch change.type {
            case .added:
                if existing == nil {
                    let salesman = firestoreSalesman.toSalesman()
                    context.insert(salesman)
                }
            case .modified:
                if let salesman = existing {
                    firestoreSalesman.update(salesman)
                }
            case .removed:
                // We soft-delete, so just mark as deleted
                existing?.deletedAt = .now
            }
            
            try context.save()
        } catch {
            syncError = error
        }
    }
    
    private func listenToProducts() {
        guard let collection = businessCollection("products") else { return }
        
        let listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges, error == nil else {
                self?.syncError = error
                return
            }
            
            Task { @MainActor in
                for change in changes {
                    self?.handleProductChange(change)
                }
            }
        }
        listeners.append(listener)
    }
    
    @MainActor
    private func handleProductChange(_ change: DocumentChange) {
        guard let context = modelContext else { return }
        
        do {
            let firestoreProduct = try change.document.data(as: FirestoreProduct.self)
            guard let uuid = UUID(uuidString: firestoreProduct.id) else { return }
            
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.id == uuid }
            )
            let existing = try context.fetch(descriptor).first
            
            switch change.type {
            case .added:
                if existing == nil {
                    let product = firestoreProduct.toProduct()
                    context.insert(product)
                }
            case .modified:
                if let product = existing {
                    firestoreProduct.update(product)
                }
            case .removed:
                existing?.deletedAt = .now
            }
            
            try context.save()
        } catch {
            syncError = error
        }
    }
    
    private func listenToTransactions() {
        guard let collection = businessCollection("transactions") else { return }
        
        let listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges, error == nil else {
                self?.syncError = error
                return
            }
            
            Task { @MainActor in
                for change in changes {
                    self?.handleTransactionChange(change)
                }
            }
        }
        listeners.append(listener)
    }
    
    @MainActor
    private func handleTransactionChange(_ change: DocumentChange) {
        guard let context = modelContext else { return }
        
        do {
            let firestoreTransaction = try change.document.data(as: FirestoreTransaction.self)
            guard let uuid = UUID(uuidString: firestoreTransaction.id) else { return }
            
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.id == uuid }
            )
            let existing = try context.fetch(descriptor).first
            
            switch change.type {
            case .added:
                if existing == nil {
                    let transaction = firestoreTransaction.toTransaction()
                    // Link salesman if exists
                    if let salesmanId = firestoreTransaction.salesmanId,
                       let salesmanUUID = UUID(uuidString: salesmanId) {
                        let salesmanDescriptor = FetchDescriptor<Salesman>(
                            predicate: #Predicate { $0.id == salesmanUUID }
                        )
                        transaction.salesman = try context.fetch(salesmanDescriptor).first
                    }
                    context.insert(transaction)
                    print("📥 [LISTENER] Inserted transaction: \(firestoreTransaction.id)")
                }
            case .modified:
                // Transactions are mostly immutable, but handle if needed
                break
            case .removed:
                // We don't delete transactions, they get reversed
                break
            }
            
            try context.save()
        } catch {
            syncError = error
        }
    }
    
    private func listenToTransactionItems() {
        guard let collection = businessCollection("transactionItems") else { return }
        
        let listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges, error == nil else {
                self?.syncError = error
                return
            }
            
            Task { @MainActor in
                for change in changes {
                    self?.handleTransactionItemChange(change)
                }
            }
        }
        listeners.append(listener)
    }
    
    @MainActor
    private func handleTransactionItemChange(_ change: DocumentChange) {
        guard let context = modelContext else { return }
        
        // Only handle additions - items don't get modified or deleted
        guard change.type == .added else { return }
        
        do {
            let firestoreItem = try change.document.data(as: FirestoreTransactionItem.self)
            guard let uuid = UUID(uuidString: firestoreItem.id) else { return }
            
            // Check if already exists
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            guard try context.fetch(descriptor).first == nil else { return }
            
            // Find the product
            guard let productUUID = UUID(uuidString: firestoreItem.productId) else { return }
            let productDescriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.id == productUUID }
            )
            guard let product = try context.fetch(productDescriptor).first else {
                print("⚠️ [LISTENER] No product found for item: \(firestoreItem.productId)")
                return
            }
            
            // Find the transaction
            guard let transactionUUID = UUID(uuidString: firestoreItem.transactionId) else { return }
            let transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.id == transactionUUID }
            )
            guard let transaction = try context.fetch(transactionDescriptor).first else {
                print("⚠️ [LISTENER] No transaction found for item: \(firestoreItem.transactionId)")
                return
            }
            
            // Create and link the item
            let item = firestoreItem.toTransactionItem(product: product)
            item.transaction = transaction
            transaction.items.append(item)
            context.insert(item)
            print("📥 [LISTENER] Inserted transaction item for transaction: \(firestoreItem.transactionId)")
            
            try context.save()
        } catch {
            syncError = error
        }
    }
    
    private func listenToInstallments() {
        guard let collection = businessCollection("installments") else { return }
        
        let listener = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let changes = snapshot?.documentChanges, error == nil else {
                self?.syncError = error
                return
            }
            
            Task { @MainActor in
                for change in changes {
                    self?.handleInstallmentChange(change)
                }
            }
        }
        listeners.append(listener)
    }
    
    @MainActor
    private func handleInstallmentChange(_ change: DocumentChange) {
        guard let context = modelContext else { return }
        
        do {
            let firestoreInstallment = try change.document.data(as: FirestoreInstallment.self)
            guard let uuid = UUID(uuidString: firestoreInstallment.id) else { return }
            
            let descriptor = FetchDescriptor<Installment>(
                predicate: #Predicate { $0.id == uuid }
            )
            let existing = try context.fetch(descriptor).first
            
            switch change.type {
            case .added:
                if existing == nil {
                    let installment = firestoreInstallment.toInstallment()
                    // Link to transaction
                    if let transactionUUID = UUID(uuidString: firestoreInstallment.transactionId) {
                        let transactionDescriptor = FetchDescriptor<Transaction>(
                            predicate: #Predicate { $0.id == transactionUUID }
                        )
                        if let transaction = try context.fetch(transactionDescriptor).first {
                            installment.transaction = transaction
                            transaction.installments.append(installment)
                        }
                    }
                    context.insert(installment)
                    print("📥 [LISTENER] Inserted installment: \(firestoreInstallment.id)")
                }
            case .modified:
                if let installment = existing {
                    firestoreInstallment.update(installment)
                }
            case .removed:
                break
            }
            
            try context.save()
        } catch {
            syncError = error
        }
    }
    
    // MARK: - Initial Sync
    
    private func performInitialSync() {
        Task {
            print("🔄 [SYNC] performInitialSync() started")
            isSyncing = true
            defer { isSyncing = false }
            
            do {
                // Check if local database is empty (new device)
                let hasLocal = await hasLocalData()
                print("🔄 [SYNC] hasLocalData: \(hasLocal)")
                
                if hasLocal {
                    // Existing device - push local changes to cloud
                    print("🔄 [SYNC] Has local data - pushing to cloud...")
                    try await pushAllLocalData()
                    print("✅ [SYNC] Push completed")
                } else {
                    // New device - pull data from cloud
                    print("🔄 [SYNC] No local data - pulling from cloud...")
                    try await pullAllData()
                    print("✅ [SYNC] Pull completed")
                }
                
                lastSyncDate = .now
                syncError = nil
                print("✅ [SYNC] Initial sync finished successfully")
                
                // Set up real-time listeners AFTER initial sync to avoid duplicates
                print("🔄 [SYNC] Setting up listeners...")
                await MainActor.run {
                    setupListeners()
                }
                print("✅ [SYNC] Listeners set up")
            } catch {
                print("❌ [SYNC] Error during initial sync: \(error)")
                syncError = error
            }
        }
    }
    
    private func hasLocalData() async -> Bool {
        guard let context = modelContext else {
            print("⚠️ [SYNC] hasLocalData: no modelContext")
            return false
        }
        
        return await MainActor.run {
            let salesmenCount = (try? context.fetchCount(FetchDescriptor<Salesman>())) ?? 0
            let productsCount = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
            print("🔍 [SYNC] Local counts - Salesmen: \(salesmenCount), Products: \(productsCount)")
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
}

import Foundation
import SwiftData
import Observation

/// ViewModel for HomeView that handles data loading and aggregation off the main thread
/// to prevent UI hangs from expensive computed properties.
@MainActor
@Observable
final class HomeViewModel {
    
    // MARK: - State
    
    private(set) var isLoading: Bool = true
    
    // MARK: - Today's Metrics
    
    private(set) var todayCashReceived: Decimal = 0
    private(set) var todayCreditGiven: Decimal = 0
    private(set) var todaySalesCount: Int = 0
    
    // MARK: - Installments
    
    private(set) var overdueInstallmentsCount: Int = 0
    private(set) var dueThisWeekInstallmentsCount: Int = 0
    private(set) var overdueAmount: Decimal = 0
    
    // MARK: - Outstanding
    
    private(set) var totalOutstanding: Decimal = 0
    
    // MARK: - Inventory
    
    private(set) var totalProductsCount: Int = 0
    private(set) var lowStockProductsCount: Int = 0
    
    // MARK: - This Month
    
    private(set) var thisMonthSales: Decimal = 0
    private(set) var thisMonthCollected: Decimal = 0
    
    // MARK: - Init
    
    init() {}
    
    /// For testing: initialize with a ModelContext and load immediately
    init(modelContext: ModelContext) {
        Task {
            await loadData(context: modelContext)
        }
    }
    
    // MARK: - Data Loading
    
    /// Loads all dashboard data. Call this from .task {} modifier.
    func loadData(context: ModelContext) async {
        isLoading = true
        
        // Perform heavy computations
        await computeMetrics(context: context)
        
        isLoading = false
    }
    
    /// Computes all metrics. This method does the heavy lifting.
    private func computeMetrics(context: ModelContext) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfWeek = WorkWeekManager.endOfWorkWeek()
        
        // Fetch all data
        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.reversedBy == nil }
        )
        let productDescriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { $0.deletedAt == nil }
        )
        let customerDescriptor = FetchDescriptor<Customer>(
            predicate: #Predicate<Customer> { $0.deletedAt == nil }
        )
        let installmentDescriptor = FetchDescriptor<Installment>(
            predicate: #Predicate<Installment> { $0.isPaid == false }
        )
        
        do {
            let allTransactions = try context.fetch(transactionDescriptor)
            let products = try context.fetch(productDescriptor)
            let customers = try context.fetch(customerDescriptor)
            let unpaidInstallments = try context.fetch(installmentDescriptor)
            
            // Today's transactions
            let todayTransactions = allTransactions.filter { calendar.isDate($0.occurredAt, inSameDayAs: today) }
            
            // Today's cash received (payments)
            todayCashReceived = todayTransactions
                .filter { $0.type == .payment }
                .reduce(Decimal(0)) { $0 + abs($1.amount) }
            
            // Today's credit given (installment distributions)
            todayCreditGiven = todayTransactions
                .filter { $0.type == .distribution && $0.paymentType == .installment }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            // Today's sales count
            todaySalesCount = todayTransactions.filter { $0.type == .distribution }.count
            
            // Overdue installments
            let overdueInstallments = unpaidInstallments.filter { $0.isOverdue }
            overdueInstallmentsCount = overdueInstallments.count
            overdueAmount = overdueInstallments.reduce(Decimal(0)) { $0 + $1.amount }
            
            // Due this week installments
            let dueThisWeek = unpaidInstallments.filter { !$0.isOverdue && $0.dueDate <= endOfWeek }
            dueThisWeekInstallmentsCount = dueThisWeek.count
            
            // Total outstanding (positive balances only)
            totalOutstanding = customers.reduce(Decimal(0)) { sum, customer in
                sum + max(0, customer.balance)
            }
            
            // Inventory
            totalProductsCount = products.count
            lowStockProductsCount = products.filter { 
                $0.stockStatus == .low || $0.stockStatus == .outOfStock 
            }.count
            
            // This month metrics
            let thisMonthTransactions = allTransactions.filter { $0.occurredAt >= startOfMonth }
            
            thisMonthSales = thisMonthTransactions
                .filter { $0.type == .distribution }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            thisMonthCollected = thisMonthTransactions
                .filter { $0.type == .payment }
                .reduce(Decimal(0)) { $0 + abs($1.amount) }
            
        } catch {
            // Log error but don't crash - show zeros
            debugPrint("HomeViewModel failed to fetch data: \(error)")
        }
    }
}

//
//  HomeViewModelTests.swift
//  FeasoTests
//
//  Created by Claude on 8/16/26.
//

import Testing
import Foundation
import SwiftData
@testable import Feaso

@MainActor
struct HomeViewModelTests {
    
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Customer.self, Product.self, Transaction.self, TransactionItem.self, Installment.self,
            configurations: config
        )
    }
    
    private func makeCustomer(name: String, in context: ModelContext) -> Customer {
        let customer = Customer(name: name)
        context.insert(customer)
        return customer
    }
    
    private func makeProduct(name: String, cashPrice: Decimal, openingStock: Decimal, reorderThreshold: Decimal? = nil, in context: ModelContext) -> Product {
        let product = Product(name: name, costPrice: cashPrice * 0.8, cashPrice: cashPrice, openingStock: openingStock, reorderThreshold: reorderThreshold)
        context.insert(product)
        return product
    }
    
    // MARK: - Initial State
    
    @Test func initialStateIsLoading() throws {
        let viewModel = HomeViewModel()
        
        #expect(viewModel.isLoading == true)
    }
    
    // MARK: - Today's Metrics
    
    @Test func todayCashReceivedSumsPayments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 50, openingStock: 100, in: context)
        
        // Create distribution (so customer owes money)
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 10, unitPriceOverride: nil)], in: context)
        
        // Record payment today
        try LedgerService.recordPayment(from: customer, amount: 200, in: context)
        try LedgerService.recordPayment(from: customer, amount: 100, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.todayCashReceived == 300)
    }
    
    @Test func todayCreditGivenSumsInstallmentDistributions() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Phone", cashPrice: 100, openingStock: 50, in: context)
        
        // Record installment distribution today
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 2,
            firstDueDate: Date(),
            interval: .monthly
        )
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product: product, quantity: 5, unitPriceOverride: nil)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.todayCreditGiven == 500)
    }
    
    @Test func todaySalesCountsDistributions() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 50, openingStock: 100, in: context)
        
        // Create 3 distributions today
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 1, unitPriceOverride: nil)], in: context)
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 2, unitPriceOverride: nil)], in: context)
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 3, unitPriceOverride: nil)], in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.todaySalesCount == 3)
    }
    
    // MARK: - Installment Tracking
    
    @Test func overdueInstallmentsFiltersCorrectly() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Phone", cashPrice: 100, openingStock: 50, in: context)
        
        // Create overdue installment (past due date)
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 2,
            firstDueDate: pastDate,
            interval: .monthly
        )
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product: product, quantity: 1, unitPriceOverride: nil)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.overdueInstallmentsCount == 1)
    }
    
    @Test func dueThisWeekInstallmentsFiltersCorrectly() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Phone", cashPrice: 100, openingStock: 50, in: context)
        
        // Create installment due in 3 days (within week)
        let nearFutureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 1,
            firstDueDate: nearFutureDate,
            intervalDays: 30
        )
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product: product, quantity: 1, unitPriceOverride: nil)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.dueThisWeekInstallmentsCount >= 1)
    }
    
    // MARK: - Outstanding Balance
    
    @Test func totalOutstandingSumsPositiveBalances() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer1 = makeCustomer(name: "Ahmed", in: context)
        let customer2 = makeCustomer(name: "Mohamed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        // Ahmed owes 500
        try LedgerService.recordDistribution(to: customer1, items: [(product: product, quantity: 5, unitPriceOverride: nil)], in: context)
        
        // Mohamed owes 300
        try LedgerService.recordDistribution(to: customer2, items: [(product: product, quantity: 3, unitPriceOverride: nil)], in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.totalOutstanding == 800)
    }
    
    @Test func totalOutstandingIgnoresNegativeBalances() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        // Customer owes 500
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 5, unitPriceOverride: nil)], in: context)
        
        // Customer overpays by 100 (balance becomes -100)
        try LedgerService.recordPayment(from: customer, amount: 600, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        // Negative balance should not be counted
        #expect(viewModel.totalOutstanding == 0)
    }
    
    @Test func overdueAmountSumsOverdueInstallments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Phone", cashPrice: 300, openingStock: 50, in: context)
        
        // Create overdue installments
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: pastDate,
            intervalDays: 2  // All 3 will be overdue
        )
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product: product, quantity: 1, unitPriceOverride: nil)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.overdueAmount == 300)
    }
    
    // MARK: - Inventory
    
    @Test func lowStockProductsCountsCorrectly() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        
        // Healthy stock product
        _ = makeProduct(name: "Water", cashPrice: 10, openingStock: 100, reorderThreshold: 10, in: context)
        
        // Low stock product
        _ = makeProduct(name: "Soda", cashPrice: 15, openingStock: 5, reorderThreshold: 10, in: context)
        
        // Out of stock product
        _ = makeProduct(name: "Juice", cashPrice: 20, openingStock: 0, reorderThreshold: 10, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.lowStockProductsCount == 2)  // Low + Out of stock
        #expect(viewModel.totalProductsCount == 3)
    }
    
    // MARK: - This Month Metrics
    
    @Test func thisMonthSalesSumsDistributions() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        // Create distribution this month
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 5, unitPriceOverride: nil)], in: context)
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 3, unitPriceOverride: nil)], in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.thisMonthSales == 800)
    }
    
    @Test func thisMonthCollectedSumsPayments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        // Create debt first
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 10, unitPriceOverride: nil)], in: context)
        
        // Record payments this month
        try LedgerService.recordPayment(from: customer, amount: 300, in: context)
        try LedgerService.recordPayment(from: customer, amount: 200, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.thisMonthCollected == 500)
    }
    
    // MARK: - Reversed Transactions Excluded
    
    @Test func reversedTransactionsNotCounted() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        // Create and reverse a distribution
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 5, unitPriceOverride: nil)], in: context)
        let distribution = try #require(customer.transactions.first { $0.type == .distribution })
        try LedgerService.reverse(distribution, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.todaySalesCount == 0)  // Reversed distribution not counted
        #expect(viewModel.totalOutstanding == 0)
    }
    
    // MARK: - Refresh Updates Data
    
    @Test func refreshUpdatesData() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let customer = makeCustomer(name: "Ahmed", in: context)
        let product = makeProduct(name: "Water", cashPrice: 100, openingStock: 200, in: context)
        
        let viewModel = HomeViewModel()
        await viewModel.loadData(context: context)
        
        #expect(viewModel.todaySalesCount == 0)
        
        // Add a distribution
        try LedgerService.recordDistribution(to: customer, items: [(product: product, quantity: 1, unitPriceOverride: nil)], in: context)
        
        // Refresh should pick it up
        await viewModel.loadData()
        
        #expect(viewModel.todaySalesCount == 1)
    }
}

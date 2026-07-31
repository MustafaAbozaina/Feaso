//
//  FeasoTests.swift
//  FeasoTests
//
//  Created by Mustafa Abozaina on 6/24/26.
//

import Testing
import Foundation
import SwiftData
@testable import Feaso

@MainActor
struct LedgerTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Customer.self, Product.self, Transaction.self, TransactionItem.self, Installment.self,
            configurations: config
        )
    }

    private func makeCustomerAndProduct(
        in context: ModelContext,
        cashPrice: Decimal = 50
    ) -> (Customer, Product) {
        let customer = Customer(name: "Ahmed")
        let product = Product(name: "Water", costPrice: 40, cashPrice: cashPrice, openingStock: 100)
        context.insert(customer)
        context.insert(product)
        return (customer, product)
    }

    // MARK: - Core flows

    @Test func distributionIncreasesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)

        #expect(customer.balance == 500)
    }

    @Test func paymentReducesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        try LedgerService.recordPayment(from: customer, amount: 200, in: context)

        #expect(customer.balance == 300)
    }

    @Test func returnReducesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        try LedgerService.recordReturn(from: customer, items: [(product, 4)], in: context)

        #expect(customer.balance == 300)
    }

    // MARK: - Return pricing (historical, not current)

    @Test func returnAfterPriceIncreaseUsesDistributionPrice() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, cashPrice: 50)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        product.cashPrice = 60
        try LedgerService.recordReturn(from: customer, items: [(product, 5)], in: context)

        // Credited 5 × 50 (distribution price), not 5 × 60 (current price)
        #expect(customer.balance == 250)
    }

    @Test func returnConsumesPriceLotsFIFO() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, cashPrice: 50)
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], occurredAt: t1, in: context)
        product.cashPrice = 60
        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], occurredAt: t2, in: context)
        try LedgerService.recordReturn(from: customer, items: [(product, 15)], in: context)

        // Credit = 10 × 50 + 5 × 60 = 800; balance = 500 + 600 − 800
        #expect(customer.balance == 300)
    }

    @Test func partialReturnsKeepConsumingLotsInOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, cashPrice: 50)
        let t1 = Date(timeIntervalSince1970: 1_000)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], occurredAt: t1, in: context)
        try LedgerService.recordReturn(from: customer, items: [(product, 4)], occurredAt: Date(timeIntervalSince1970: 2_000), in: context)

        let lots = LedgerService.outstandingLots(for: customer, product: product)
        #expect(lots.count == 1)
        #expect(lots.first?.quantity == 6)
        #expect(lots.first?.unitPrice == 50)
        #expect(LedgerService.value(of: 6, from: lots) == 300)
    }

    @Test func overReturnThrowsAndLeavesLedgerUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)

        #expect(throws: LedgerError.insufficientReturnableQuantity) {
            try LedgerService.recordReturn(from: customer, items: [(product, 11)], in: context)
        }
        #expect(customer.balance == 500)
    }

    // MARK: - Reversals

    @Test func reversingDistributionRestoresZeroBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        let distribution = try #require(customer.transactions.first { $0.type == .distribution })

        try LedgerService.reverse(distribution, in: context)

        #expect(customer.balance == 0)
    }

    @Test func reversingPaymentRestoresDebt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        try LedgerService.recordPayment(from: customer, amount: 200, in: context)
        let payment = try #require(customer.transactions.first { $0.type == .payment })

        try LedgerService.reverse(payment, in: context)

        #expect(customer.balance == 500)
    }

    @Test func reversingTwiceThrows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        let distribution = try #require(customer.transactions.first { $0.type == .distribution })
        try LedgerService.reverse(distribution, in: context)

        #expect(throws: LedgerError.alreadyReversed) {
            try LedgerService.reverse(distribution, in: context)
        }
        #expect(customer.balance == 0)
    }

    @Test func reversedDistributionIsNotReturnable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        let distribution = try #require(customer.transactions.first { $0.type == .distribution })
        try LedgerService.reverse(distribution, in: context)

        #expect(customer.returnableProducts.isEmpty)
        #expect(LedgerService.outstandingLots(for: customer, product: product).isEmpty)
    }

    // MARK: - Mixed history

    @Test func mixedHistoryBalancesCorrectly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, cashPrice: 50)

        try LedgerService.recordDistribution(to: customer, items: [(product, 20)], occurredAt: Date(timeIntervalSince1970: 1_000), in: context)  // +1000
        try LedgerService.recordPayment(from: customer, amount: 400, in: context)                                                                 // −400
        try LedgerService.recordReturn(from: customer, items: [(product, 5)], occurredAt: Date(timeIntervalSince1970: 2_000), in: context)        // −250
        let payment = try #require(customer.transactions.first { $0.type == .payment })
        try LedgerService.reverse(payment, in: context)                                                                                           // +400

        #expect(customer.balance == 750)
        #expect(customer.returnableProducts[product] == 15)
    }

    @Test func currentStockReflectsDistributionsAndReturns() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)

        try LedgerService.recordDistribution(to: customer, items: [(product, 10)], in: context)
        try LedgerService.recordReturn(from: customer, items: [(product, 4)], in: context)

        #expect(product.currentStock == 94)  // 100 − 10 + 4
    }
}

// MARK: - Installment Tests

@MainActor
struct InstallmentTests {
    
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Customer.self, Product.self, Transaction.self, TransactionItem.self, Installment.self,
            configurations: config
        )
    }
    
    private func makeCustomerAndProduct(
        in context: ModelContext,
        cashPrice: Decimal = 100,
        installmentPrice: Decimal = 120
    ) -> (Customer, Product) {
        let customer = Customer(name: "Ahmed")
        let product = Product(name: "Phone", costPrice: 80, cashPrice: cashPrice, installmentPrice: installmentPrice, openingStock: 50)
        context.insert(customer)
        context.insert(product)
        return (customer, product)
    }
    
    // MARK: - Installment Creation
    
    @Test func installmentDistributionCreatesInstallments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        let firstDueDate = Date()
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: firstDueDate,
            interval: .biweekly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 10)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        #expect(transaction.hasInstallments)
        #expect(transaction.installments.count == 3)
    }
    
    @Test func installmentAmountsEqualTransactionTotal() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 100)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 10)],  // 10 × 100 = 1000
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        #expect(transaction.amount == 1000)
        #expect(transaction.totalInstallmentAmount == 1000)
    }
    
    @Test func installmentDatesAreCorrectlySpaced() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        let calendar = Calendar.current
        let firstDueDate = calendar.startOfDay(for: Date())
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 4,
            firstDueDate: firstDueDate,
            interval: .weekly  // 7 days
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 5)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        let sorted = transaction.sortedInstallments
        
        #expect(sorted.count == 4)
        #expect(sorted[0].sequenceNumber == 1)
        #expect(sorted[1].sequenceNumber == 2)
        #expect(sorted[2].sequenceNumber == 3)
        #expect(sorted[3].sequenceNumber == 4)
        
        // Check dates are 7 days apart
        for i in 1..<sorted.count {
            let daysBetween = calendar.dateComponents([.day], from: sorted[i-1].dueDate, to: sorted[i].dueDate).day
            #expect(daysBetween == 7)
        }
    }
    
    @Test func installmentAmountsDistributedEvenly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 100)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 10)],  // 10 × 100 = 1000
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        let sorted = transaction.sortedInstallments
        
        // 1000 / 3 = 333.33... so expect 333.33, 333.33, 333.34 (remainder in last)
        let sum = sorted.reduce(Decimal.zero) { $0 + $1.amount }
        #expect(sum == 1000)
    }
    
    // MARK: - Installment Payment
    
    @Test func markingInstallmentPaidCreatesPaymentTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 300)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],  // 1 × 300 = 300
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        #expect(customer.balance == 300)
        
        let transaction = try #require(customer.transactions.first { $0.type == .distribution })
        let installment = try #require(transaction.sortedInstallments.first)
        
        try LedgerService.markInstallmentPaid(installment, in: context)
        
        #expect(installment.isPaid)
        #expect(installment.paymentTransaction != nil)
        #expect(customer.balance == 200)  // 300 - 100 (one installment paid)
    }
    
    @Test func markingInstallmentUnpaidReversesPayment() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 300)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first { $0.type == .distribution })
        let installment = try #require(transaction.sortedInstallments.first)
        
        try LedgerService.markInstallmentPaid(installment, in: context)
        #expect(customer.balance == 200)
        
        try LedgerService.markInstallmentUnpaid(installment, in: context)
        #expect(!installment.isPaid)
        #expect(customer.balance == 300)  // Balance restored
    }
    
    @Test func payingAllInstallmentsSettlesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 300)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first { $0.type == .distribution })
        
        for installment in transaction.sortedInstallments {
            try LedgerService.markInstallmentPaid(installment, in: context)
        }
        
        #expect(customer.balance == 0)
        #expect(transaction.paidInstallmentsCount == 3)
        #expect(transaction.remainingInstallmentAmount == 0)
    }
    
    // MARK: - Installment Status
    
    @Test func overdueInstallmentDetection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 2,
            firstDueDate: pastDate,
            intervalDays: 30
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        let firstInstallment = try #require(transaction.sortedInstallments.first)
        
        #expect(firstInstallment.isOverdue)
        #expect(firstInstallment.status == .overdue)
        #expect(transaction.hasOverdueInstallments)
        #expect(transaction.overdueInstallments.count == 1)
    }
    
    @Test func dueSoonInstallmentDetection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        let nearFutureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 1,
            firstDueDate: nearFutureDate,
            intervalDays: 30
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        let installment = try #require(transaction.sortedInstallments.first)
        
        #expect(!installment.isOverdue)
        #expect(installment.status == .dueSoon)
    }
    
    @Test func paidInstallmentNotOverdue() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 1,
            firstDueDate: pastDate,
            intervalDays: 30
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        let installment = try #require(transaction.sortedInstallments.first)
        
        try LedgerService.markInstallmentPaid(installment, in: context)
        
        #expect(!installment.isOverdue)  // Paid installments are never overdue
        #expect(installment.status == .paid)
        #expect(!transaction.hasOverdueInstallments)
    }
    
    // MARK: - Transaction Helpers
    
    @Test func transactionInstallmentHelpers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 600)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 3,
            firstDueDate: Date(),
            interval: .monthly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],  // 600 total
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        
        #expect(transaction.hasInstallments)
        #expect(transaction.totalInstallmentAmount == 600)
        #expect(transaction.paidInstallmentAmount == 0)
        #expect(transaction.remainingInstallmentAmount == 600)
        #expect(transaction.paidInstallmentsCount == 0)
        
        // Pay first installment (200)
        let first = try #require(transaction.sortedInstallments.first)
        try LedgerService.markInstallmentPaid(first, in: context)
        
        #expect(transaction.paidInstallmentsCount == 1)
        #expect(transaction.paidInstallmentAmount == 200)
        #expect(transaction.remainingInstallmentAmount == 400)
        
        // Next due should be second installment
        let nextDue = transaction.nextDueInstallment
        #expect(nextDue?.sequenceNumber == 2)
    }
    
    // MARK: - Cash Distribution Has No Installments
    
    @Test func cashDistributionHasNoInstallments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 5)],
            paymentType: .cash,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        #expect(!transaction.hasInstallments)
        #expect(transaction.installments.isEmpty)
    }
    
    @Test func installmentDistributionWithoutConfigHasNoInstallments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context)
        
        // Installment payment type but no config
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 5)],
            paymentType: .installment,
            installmentConfig: nil,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        #expect(!transaction.hasInstallments)
    }
    
    // MARK: - Update Installments
    
    @Test func updateInstallmentsReplacesSchedule() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (customer, product) = makeCustomerAndProduct(in: context, installmentPrice: 400)
        
        let config = LedgerService.InstallmentConfig(
            numberOfInstallments: 4,
            firstDueDate: Date(),
            interval: .weekly
        )
        
        try LedgerService.recordDistribution(
            to: customer,
            items: [(product, 1)],
            paymentType: .installment,
            installmentConfig: config,
            in: context
        )
        
        let transaction = try #require(customer.transactions.first)
        #expect(transaction.installments.count == 4)
        
        // Update to 2 installments
        let newSchedule = [
            (sequenceNumber: 1, amount: Decimal(200), dueDate: Date()),
            (sequenceNumber: 2, amount: Decimal(200), dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!)
        ]
        
        try LedgerService.updateInstallments(for: transaction, newInstallments: newSchedule, in: context)
        
        #expect(transaction.installments.count == 2)
        #expect(transaction.totalInstallmentAmount == 400)
    }
}

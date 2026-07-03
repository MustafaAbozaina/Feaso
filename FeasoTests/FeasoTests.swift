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
            for: Salesman.self, Product.self, Transaction.self, TransactionItem.self,
            configurations: config
        )
    }

    private func makeSalesmanAndProduct(
        in context: ModelContext,
        sellingPrice: Decimal = 50
    ) -> (Salesman, Product) {
        let salesman = Salesman(name: "Ahmed")
        let product = Product(name: "Water", costPrice: 40, sellingPrice: sellingPrice, openingStock: 100)
        context.insert(salesman)
        context.insert(product)
        return (salesman, product)
    }

    // MARK: - Core flows

    @Test func distributionIncreasesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)

        #expect(salesman.balance == 500)
    }

    @Test func paymentReducesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        try LedgerService.recordPayment(from: salesman, amount: 200, in: context)

        #expect(salesman.balance == 300)
    }

    @Test func returnReducesBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        try LedgerService.recordReturn(from: salesman, items: [(product, 4)], in: context)

        #expect(salesman.balance == 300)
    }

    // MARK: - Return pricing (historical, not current)

    @Test func returnAfterPriceIncreaseUsesDistributionPrice() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context, sellingPrice: 50)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        product.sellingPrice = 60
        try LedgerService.recordReturn(from: salesman, items: [(product, 5)], in: context)

        // Credited 5 × 50 (distribution price), not 5 × 60 (current price)
        #expect(salesman.balance == 250)
    }

    @Test func returnConsumesPriceLotsFIFO() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context, sellingPrice: 50)
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], occurredAt: t1, in: context)
        product.sellingPrice = 60
        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], occurredAt: t2, in: context)
        try LedgerService.recordReturn(from: salesman, items: [(product, 15)], in: context)

        // Credit = 10 × 50 + 5 × 60 = 800; balance = 500 + 600 − 800
        #expect(salesman.balance == 300)
    }

    @Test func partialReturnsKeepConsumingLotsInOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context, sellingPrice: 50)
        let t1 = Date(timeIntervalSince1970: 1_000)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], occurredAt: t1, in: context)
        try LedgerService.recordReturn(from: salesman, items: [(product, 4)], occurredAt: Date(timeIntervalSince1970: 2_000), in: context)

        let lots = LedgerService.outstandingLots(for: salesman, product: product)
        #expect(lots.count == 1)
        #expect(lots.first?.quantity == 6)
        #expect(lots.first?.unitPrice == 50)
        #expect(LedgerService.value(of: 6, from: lots) == 300)
    }

    @Test func overReturnThrowsAndLeavesLedgerUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)

        #expect(throws: LedgerError.insufficientReturnableQuantity) {
            try LedgerService.recordReturn(from: salesman, items: [(product, 11)], in: context)
        }
        #expect(salesman.balance == 500)
    }

    // MARK: - Reversals

    @Test func reversingDistributionRestoresZeroBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        let distribution = try #require(salesman.transactions.first { $0.type == .distribution })

        try LedgerService.reverse(distribution, in: context)

        #expect(salesman.balance == 0)
    }

    @Test func reversingPaymentRestoresDebt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        try LedgerService.recordPayment(from: salesman, amount: 200, in: context)
        let payment = try #require(salesman.transactions.first { $0.type == .payment })

        try LedgerService.reverse(payment, in: context)

        #expect(salesman.balance == 500)
    }

    @Test func reversingTwiceThrows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        let distribution = try #require(salesman.transactions.first { $0.type == .distribution })
        try LedgerService.reverse(distribution, in: context)

        #expect(throws: LedgerError.alreadyReversed) {
            try LedgerService.reverse(distribution, in: context)
        }
        #expect(salesman.balance == 0)
    }

    @Test func reversedDistributionIsNotReturnable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        let distribution = try #require(salesman.transactions.first { $0.type == .distribution })
        try LedgerService.reverse(distribution, in: context)

        #expect(salesman.returnableProducts.isEmpty)
        #expect(LedgerService.outstandingLots(for: salesman, product: product).isEmpty)
    }

    // MARK: - Mixed history

    @Test func mixedHistoryBalancesCorrectly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context, sellingPrice: 50)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 20)], occurredAt: Date(timeIntervalSince1970: 1_000), in: context)  // +1000
        try LedgerService.recordPayment(from: salesman, amount: 400, in: context)                                                                 // −400
        try LedgerService.recordReturn(from: salesman, items: [(product, 5)], occurredAt: Date(timeIntervalSince1970: 2_000), in: context)        // −250
        let payment = try #require(salesman.transactions.first { $0.type == .payment })
        try LedgerService.reverse(payment, in: context)                                                                                           // +400

        #expect(salesman.balance == 750)
        #expect(salesman.returnableProducts[product] == 15)
    }

    @Test func currentStockReflectsDistributionsAndReturns() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (salesman, product) = makeSalesmanAndProduct(in: context)

        try LedgerService.recordDistribution(to: salesman, items: [(product, 10)], in: context)
        try LedgerService.recordReturn(from: salesman, items: [(product, 4)], in: context)

        #expect(product.currentStock == 94)  // 100 − 10 + 4
    }
}

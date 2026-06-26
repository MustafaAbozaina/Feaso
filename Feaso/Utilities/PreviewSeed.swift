import Foundation
import SwiftData

enum PreviewSeed {
    
    @MainActor
    static func populateIfEmpty(_ context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Salesman>())
        guard existing.isEmpty else { return }
        
        // MARK: - Products
        let tv = Product(
            name: "TV",
            costPrice: 7000,
            sellingPrice: 10000,
            openingStock: 50,
            reorderThreshold: 5
        )
        let soundbar = Product(
            name: "Soundbar",
            costPrice: 1400,
            sellingPrice: 2000,
            openingStock: 30,
            reorderThreshold: 5
        )
        let coffeeMachine = Product(
            name: "Coffee Machine",
            costPrice: 2100,
            sellingPrice: 3000,
            openingStock: 25,
            reorderThreshold: 3
        )
        let fan = Product(
            name: "Fan",
            costPrice: 350,
            sellingPrice: 500,
            openingStock: 100,
            reorderThreshold: 10
        )
        let toaster = Product(
            name: "Toaster",
            costPrice: 280,
            sellingPrice: 400,
            openingStock: 40,
            reorderThreshold: 5
        )
        let blender = Product(
            name: "Blender",
            costPrice: 420,
            sellingPrice: 600,
            openingStock: 35,
            reorderThreshold: 5
        )
        let microwave = Product(
            name: "Microwave",
            costPrice: 1750,
            sellingPrice: 2500,
            openingStock: 20,
            reorderThreshold: 3
        )
        let airConditioner = Product(
            name: "Air Conditioner",
            costPrice: 8400,
            sellingPrice: 12000,
            openingStock: 15,
            reorderThreshold: 2
        )
        
        let products = [tv, soundbar, coffeeMachine, fan, toaster, blender, microwave, airConditioner]
        products.forEach { context.insert($0) }
        
        // MARK: - Salesmen
        let ahmed = Salesman(name: "Ahmed", phone: "+201001234567")
        let mahmoud = Salesman(name: "Mahmoud", phone: "+201009876543")
        let yasser = Salesman(name: "Yasser", phone: "+201005551234")
        let khaled = Salesman(name: "Khaled")
        let sherif = Salesman(name: "Sherif", phone: "+201007778888", notes: "Works in Giza area")
        
        let salesmen = [ahmed, mahmoud, yasser, khaled, sherif]
        salesmen.forEach { context.insert($0) }
        
        try context.save()
        
        // MARK: - Transactions
        // Create dates going back in time
        let now = Date.now
        let daysAgo: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: -$0, to: now) ?? now }
        
        // Ahmed: Active, owes money, recent activity
        try LedgerService.recordDistribution(
            to: ahmed,
            items: [(tv, 2), (soundbar, 3)],
            occurredAt: daysAgo(5),
            in: context
        )
        try LedgerService.recordPayment(
            from: ahmed,
            amount: 15000,
            note: "Partial payment",
            occurredAt: daysAgo(3),
            in: context
        )
        try LedgerService.recordDistribution(
            to: ahmed,
            items: [(coffeeMachine, 2), (fan, 5)],
            occurredAt: daysAgo(1),
            in: context
        )
        
        // Mahmoud: Active, owes money, slightly stale (10 days)
        try LedgerService.recordDistribution(
            to: mahmoud,
            items: [(microwave, 3), (blender, 4)],
            occurredAt: daysAgo(15),
            in: context
        )
        try LedgerService.recordPayment(
            from: mahmoud,
            amount: 5000,
            occurredAt: daysAgo(10),
            in: context
        )
        
        // Yasser: Active, owes money, stale activity (20+ days - should show warning)
        try LedgerService.recordDistribution(
            to: yasser,
            items: [(airConditioner, 1), (tv, 1)],
            occurredAt: daysAgo(25),
            in: context
        )
        try LedgerService.recordPayment(
            from: yasser,
            amount: 10000,
            occurredAt: daysAgo(20),
            in: context
        )
        
        // Khaled: Settled (balance = 0)
        try LedgerService.recordDistribution(
            to: khaled,
            items: [(fan, 10), (toaster, 5)],
            occurredAt: daysAgo(30),
            in: context
        )
        try LedgerService.recordPayment(
            from: khaled,
            amount: 7000,
            note: "Full payment",
            occurredAt: daysAgo(28),
            in: context
        )
        
        // Sherif: Active, owes money, recent activity
        try LedgerService.recordDistribution(
            to: sherif,
            items: [(tv, 3), (soundbar, 2), (coffeeMachine, 1)],
            occurredAt: daysAgo(7),
            in: context
        )
        try LedgerService.recordDistribution(
            to: sherif,
            items: [(blender, 3)],
            occurredAt: daysAgo(2),
            in: context
        )
    }
}

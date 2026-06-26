# Data Model

This document defines the SwiftData schema. Every model decision here is intentional. Do not change a model without updating this file first.

## Mental model

The app is an **append-only ledger**. Three things matter:

1. **Salesmen** and **Products** are entities with stable identities. They can be soft-deleted but never hard-deleted while they have associated history.
2. **Transactions** are events. Every change to debt or stock is a transaction. Transactions are never updated and never hard-deleted. To "undo" a transaction, you record a new one that reverses it.
3. **Balance** (how much a salesman owes) and **stock** (how many of a product remain) are *derived* values computed from the transaction ledger. They are never stored.

This mental model is the entire reason the app will survive contact with reality. If you ever find yourself wanting to write a `balance` column or update a row in `transactions`, stop and re-read this section.

---

## Models

### `Salesman`

```swift
import Foundation
import SwiftData

@Model
final class Salesman {
    var id: UUID
    var name: String
    var phone: String?
    var notes: String?
    var createdAt: Date
    var deletedAt: Date?  // soft delete

    @Relationship(deleteRule: .nullify, inverse: \Transaction.salesman)
    var transactions: [Transaction] = []

    init(name: String, phone: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.notes = notes
        self.createdAt = .now
    }

    /// Computed balance. Positive = salesman owes the business.
    /// Distribution amounts are positive; payments are negative; reversals are signed appropriately.
    var balance: Decimal {
        transactions
            .filter { $0.reversedBy == nil }  // exclude reversed transactions
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var isSettled: Bool { balance == 0 }
    var isActive: Bool { deletedAt == nil }
    var lastActivityAt: Date? {
        transactions.map(\.occurredAt).max()
    }
}
```

**Notes:**
- `deletedAt == nil` means active. Soft delete only. We never `modelContext.delete(salesman)` if they have transactions.
- `balance` recomputes on every access. With one owner and ~10 salesmen with maybe ~50 transactions each, this is fine. If it ever isn't, that's a v2 problem.
- `transactions` is the SwiftData relationship — Swift property name, used in `@Query` and view code.

### `Product`

```swift
import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID
    var name: String
    var costPrice: Decimal
    var sellingPrice: Decimal
    var openingStock: Int  // initial stock when product was added
    var reorderThreshold: Int?
    var createdAt: Date
    var deletedAt: Date?  // soft delete

    @Relationship(inverse: \TransactionItem.product)
    var transactionItems: [TransactionItem] = []

    init(
        name: String,
        costPrice: Decimal,
        sellingPrice: Decimal,
        openingStock: Int = 0,
        reorderThreshold: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.costPrice = costPrice
        self.sellingPrice = sellingPrice
        self.openingStock = openingStock
        self.reorderThreshold = reorderThreshold
        self.createdAt = .now
    }

    /// Current stock = opening - distributed + returned, excluding reversed transactions.
    var currentStock: Int {
        let activeItems = transactionItems.filter {
            $0.transaction?.reversedBy == nil
        }
        let distributed = activeItems
            .filter { $0.transaction?.type == .distribution }
            .reduce(0) { $0 + $1.quantity }
        let returned = activeItems
            .filter { $0.transaction?.type == .return }
            .reduce(0) { $0 + $1.quantity }
        return openingStock - distributed + returned
    }

    var stockStatus: StockStatus {
        if currentStock <= 0 { return .outOfStock }
        if let threshold = reorderThreshold, currentStock <= threshold { return .low }
        return .healthy
    }

    var isActive: Bool { deletedAt == nil }
}

enum StockStatus {
    case healthy, low, outOfStock
}
```

**Notes:**
- `openingStock` is the initial inventory at the moment the product was added. Subsequent changes are recorded as transactions.
- If you need to manually adjust stock later (recount, breakage), create a `Transaction(type: .adjustment)` with associated `TransactionItem`s — don't edit `openingStock`.

### `TransactionType`

```swift
enum TransactionType: String, Codable, CaseIterable {
    case distribution  // products given to a salesman (debt +, stock -)
    case payment        // money received from a salesman (debt -)
    case `return`       // products returned by a salesman (debt -, stock +)
    case adjustment    // manual correction (signed amount)
}
```

### `Transaction`

```swift
import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var typeRaw: String  // stored as string; access through `type`
    var amount: Decimal  // signed: + increases debt, - decreases debt
    var occurredAt: Date
    var note: String?
    var createdAt: Date

    var salesman: Salesman?

    @Relationship(deleteRule: .cascade, inverse: \TransactionItem.transaction)
    var items: [TransactionItem] = []

    /// If this transaction was reversed by another, the reversing transaction lives here.
    var reversedBy: Transaction?

    /// If this transaction reverses another, the original lives here.
    var reverses: Transaction?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .adjustment }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: TransactionType,
        amount: Decimal,
        salesman: Salesman,
        occurredAt: Date = .now,
        note: String? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.salesman = salesman
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = .now
    }

    var isReversed: Bool { reversedBy != nil }
    var isReversal: Bool { reverses != nil }
}
```

**Notes:**
- SwiftData persists raw enum types reliably as `String`. Use the `typeRaw` + computed property pattern shown.
- `amount` is **signed**. A distribution is positive (e.g., +26,000). A payment is negative (e.g., -5,000). A return is negative. An adjustment is signed by intent. This lets `balance` be a simple `reduce(+)`.
- Cascade rule on `items`: if a transaction is hard-deleted (which we don't do), items go with it. In practice we never hard-delete.

### `TransactionItem`

```swift
import Foundation
import SwiftData

@Model
final class TransactionItem {
    var id: UUID
    var quantity: Int
    var unitPrice: Decimal  // snapshotted at transaction time

    var transaction: Transaction?
    var product: Product?

    init(product: Product, quantity: Int, unitPriceOverride: Decimal? = nil) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        // Snapshot the product's current selling price unless overridden.
        self.unitPrice = unitPriceOverride ?? product.sellingPrice
    }

    var lineTotal: Decimal {
        Decimal(quantity) * unitPrice
    }
}
```

**Critical:** `unitPrice` is **snapshotted** at creation time. If the owner changes the product's `sellingPrice` next month, every existing `TransactionItem` keeps its original price. This is what makes historical balances stable. Do not change this pattern.

---

## Why no `Business` or `User` model?

Multi-tenancy and authentication are explicitly out of v1 scope. The app has one owner on one device. Adding `Business` and `User` models now would create empty ceremony.

When v2 needs them (cloud sync, multi-customer SaaS), we will:

1. Add a `Business` model.
2. Add a `business` relationship on each top-level entity.
3. Backfill all existing local data into a single `Business` row at migration time.

This is a one-time SwiftData migration that happens once if and when the customer commits to ongoing payment. Until then, we don't pay the complexity tax.

---

## Common operations

### Recording a distribution (give products)

```swift
@MainActor
func recordDistribution(
    to salesman: Salesman,
    items: [(product: Product, quantity: Int)],
    note: String? = nil,
    in context: ModelContext
) throws {
    let total = items.reduce(Decimal(0)) { sum, item in
        sum + (Decimal(item.quantity) * item.product.sellingPrice)
    }

    let transaction = Transaction(
        type: .distribution,
        amount: total,
        salesman: salesman,
        note: note
    )
    context.insert(transaction)

    for (product, quantity) in items {
        let item = TransactionItem(product: product, quantity: quantity)
        item.transaction = transaction
        context.insert(item)
    }

    try context.save()
}
```

### Recording a payment

```swift
@MainActor
func recordPayment(
    from salesman: Salesman,
    amount: Decimal,
    note: String? = nil,
    in context: ModelContext
) throws {
    let transaction = Transaction(
        type: .payment,
        amount: -amount,  // stored as negative so it reduces balance
        salesman: salesman,
        note: note
    )
    context.insert(transaction)
    try context.save()
}
```

### Reversing a transaction

```swift
@MainActor
func reverse(
    _ original: Transaction,
    in context: ModelContext
) throws {
    guard original.reversedBy == nil else {
        throw LedgerError.alreadyReversed
    }
    let reversal = Transaction(
        type: .adjustment,
        amount: -original.amount,  // opposite sign
        salesman: original.salesman!,
        note: "Reversal"
    )
    reversal.reverses = original
    original.reversedBy = reversal
    context.insert(reversal)
    try context.save()
}

enum LedgerError: Error {
    case alreadyReversed
}
```

These operations belong in a `LedgerService` enum (no state) or as static functions. Do not scatter the logic across views.

---

## Migration plan

For v1, no migrations are needed — we ship fresh schema and don't break it. If you make any change to a `@Model` class:

1. Add a new property: SwiftData handles this automatically (lightweight migration).
2. Rename or remove a property: requires a `VersionedSchema` and explicit migration plan. Do not do this in v1. If you find yourself wanting to, talk to Mustafa first.

---

## Seed data for development

A debug seed (only built into the Debug configuration) populates the SwiftData store with realistic test data:

- 5 salesmen (Ahmed, Mahmoud, Yasser, Khaled, Sherif)
- 8 products (TV, Soundbar, Coffee machine, Fan, Toaster, etc.)
- 20-30 transactions across the salesmen, mixed distributions and payments

Implementation lives in `Utilities/PreviewSeed.swift`. See step 4 of `BUILD_PLAN.md`.

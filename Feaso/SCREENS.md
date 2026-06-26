# Screens

Six screens make the MVP. Visual reference is in `docs/mockups.html` — open it in a browser when implementing. This document covers behavior, state, edge cases, and interaction details that pixels alone can't show.

## Navigation map

```
Root (TabView)
├── Salesmen tab
│   ├── SalesmenListView (1)
│   │   └── SalesmanDetailView (2)
│   │       ├── GiveProductsView (3)
│   │       │   └── ProductPickerView (6)  [sheet]
│   │       └── RecordPaymentView (4)
│   └── (toolbar: Add Salesman → SalesmanEditorView)  [sheet]
└── Products tab
    ├── ProductsListView (5)
    └── (toolbar: Add Product → ProductEditorView)  [sheet]
```

Two tabs. Most flows live under Salesmen. Products is secondary.

---

## Screen 1 — Salesmen List (Home)

**File:** `Features/Salesmen/SalesmenListView.swift`

**Purpose:** The owner opens this screen first. He sees who owes him what, sorted by amount descending. He taps a row to see history or record activity.

### Layout

- Navigation title: "Salesmen" (large title).
- Above the list: business header label (small caps, "HANY DISTRIBUTION" for now — hardcode the business name in v1, configurable in v2).
- Summary card: total outstanding across all active salesmen, with count.
- Section: "Owed to you" — active salesmen with balance > 0, sorted by balance descending.
- Section: "Settled" — active salesmen with balance == 0, alphabetical, visually muted (opacity 0.6).
- Each row: name, last activity date (relative — "Today", "2 days ago", "18 days ago"), balance, "EGP" unit small.
- Toolbar: "+" button (top-right) → opens `SalesmanEditorView` as a sheet to add a new salesman.

### Data

```swift
@Query(filter: #Predicate<Salesman> { $0.deletedAt == nil })
private var salesmen: [Salesman]
```

Sort the array in computed properties:

```swift
private var owing: [Salesman] {
    salesmen.filter { $0.balance > 0 }.sorted { $0.balance > $1.balance }
}
private var settled: [Salesman] {
    salesmen.filter { $0.balance == 0 }.sorted { $0.name < $1.name }
}
private var totalOutstanding: Decimal {
    owing.reduce(Decimal(0)) { $0 + $1.balance }
}
```

### States

- **Empty (no salesmen):** show a centered placeholder with an illustration glyph (`Image(systemName: "person.2")`) and copy: *"Add your first salesman to start tracking distributions."* + a "Add Salesman" button.
- **Loaded with data:** as designed.
- **Loading:** not applicable — SwiftData is synchronous on read.

### Interactions

- Tap row → push `SalesmanDetailView(salesman:)` onto the navigation stack.
- "+" toolbar button → present `SalesmanEditorView()` as a sheet.

### Edge cases

- Salesman with very long name (> 20 chars): truncate with ellipsis.
- More than 50 salesmen: scrolling List handles this. Add search in v2 if needed.
- Last activity "today" should reflect the most recent transaction's `occurredAt` formatted with `RelativeDateTimeFormatter`.

### Warning state on stale activity

A salesman with `lastActivityAt` more than 14 days ago shows their "last activity" label in `Color.theme.warning` color instead of `ink2`. This is the visual cue for stale debt. Threshold is hardcoded at 14 days for v1.

---

## Screen 2 — Salesman Detail

**File:** `Features/Salesmen/SalesmanDetailView.swift`

**Purpose:** Full balance + full history for one salesman. Two action buttons for the two things the owner does here: give products or record a payment.

### Layout

- Navigation title: the salesman's name (inline, not large).
- Trailing toolbar: "Edit" button → opens `SalesmanEditorView(salesman:)` as a sheet.
- **Balance hero card** (top):
  - Label: "CURRENTLY OWES YOU" (small caps, accent color).
  - Amount: large (38pt semibold), accent color, with "EGP" unit smaller and lighter beside it.
  - Trajectory line: if balance has decreased from a higher historical peak, show "Down from X over Y weeks". Compute this from the salesman's highest historical balance over the last 90 days.
- **Action row** (two buttons, equal width):
  - "Gave products" — primary filled button → push `GiveProductsView(salesman:)`.
  - "Record payment" — secondary outlined button → push `RecordPaymentView(salesman:)`.
- **Activity** section:
  - List of transactions, newest first.
  - Each row:
    - Left: circular icon (✓ in success-bg for payments, → in accent-bg for distributions, ↶ for adjustments/reversals).
    - Middle: short title ("Payment received", "Gave products", "Reversed payment") + 1-2 line detail. For distributions: list items as "2 × TV", "3 × Soundbar". For payments: show the note if present, else "Cash" as default.
    - Right: signed amount + relative date underneath.
  - Reversed transactions show with strikethrough text and reduced opacity.

### Data

Pass the `Salesman` in via init. Use `@Bindable` if you need to observe changes (for the Edit flow).

```swift
@Bindable var salesman: Salesman

private var sortedTransactions: [Transaction] {
    salesman.transactions.sorted { $0.occurredAt > $1.occurredAt }
}
```

### States

- **No history yet (new salesman, balance 0):** hide the balance hero. Show a small empty state under the action buttons: *"No activity yet. Record a distribution or payment to begin."*
- **Balance > 0, has history:** as designed.
- **Balance == 0 (paid in full):** show the hero with the amount "0" in success color and a one-line caption: "Paid in full."

### Interactions

- Tap an activity row → action sheet with options:
  - "View details" (shows a sheet with the full transaction, including all items)
  - "Reverse this transaction" (destructive, with confirmation alert)
- Already-reversed transactions: tap → action sheet with only "View details".

### Reversal flow

When the owner reverses a transaction:

1. Confirmation alert: *"Reverse this transaction? This creates a new entry that undoes it. The original is preserved for the record."*
2. On confirm: call `LedgerService.reverse(transaction:in:)`.
3. The activity list updates — the original now shows with strikethrough; the reversal appears as a new entry.

---

## Screen 3 — Give Products (Distribution)

**File:** `Features/Distribution/GiveProductsView.swift`

**Purpose:** Add a list of products with quantities, see the running total, confirm. This is the single most frequent destructive-leaning action in the app.

### Layout

- Navigation title: "Gave to [name]" (inline).
- A **cart list** of items the owner is currently adding. Each cart item is a card:
  - Product name (bold).
  - Sub-line: unit price + "X in stock".
  - Stepper (− / qty / +) on the left.
  - Line total on the right.
  - Tap the card body (not the stepper) → opens `ProductPickerView` to replace the product on this line.
- **"+ Add another product"** dashed-border card at the bottom of the cart list → opens `ProductPickerView` as a sheet.
- **Footer bar** (sticky at bottom, surface2 background):
  - Two-line preview: "Ahmed will owe" + total (current + new). Sub-line: "Current X + new Y".
  - "Confirm" primary button (full width, padded), disabled while cart is empty.

### Data

Local view state — NOT SwiftData yet, because the cart is uncommitted until the user taps Confirm.

```swift
struct LineDraft: Identifiable {
    let id = UUID()
    var product: Product
    var quantity: Int
}

@State private var lines: [LineDraft] = []

private var newTotal: Decimal {
    lines.reduce(Decimal(0)) { $0 + (Decimal($1.quantity) * $1.product.sellingPrice) }
}

private var projectedBalance: Decimal {
    salesman.balance + newTotal
}
```

### States

- **Empty cart:** show only "+ Add another product" placeholder. Confirm button is disabled.
- **Cart has items, stock OK:** Confirm enabled.
- **Cart has items, some exceed stock:** Confirm button shows but tapping it surfaces an alert: "Soundbar: only 27 in stock, cart has 30." User can either reduce quantity or proceed (we allow it for v1 — stock can go negative if the owner says so; this is a warning, not a hard block).

### Interactions

- Stepper − below 1: removes the line entirely (with no confirmation — instant).
- Stepper +: increments. If exceeds available stock, the qty number turns warning color but accepts the input.
- Tap product name area → opens `ProductPickerView` with the current product pre-selected for swap.
- "+ Add another product" → opens `ProductPickerView` (sheet).
- Confirm → calls `LedgerService.recordDistribution(...)`, pops back to `SalesmanDetailView`. The new transaction appears at the top of the activity list.

### Cancel behavior

- If the user taps the back arrow with a non-empty cart, show a confirmation: "Discard this distribution? Items will not be recorded."
- Otherwise back is silent.

---

## Screen 4 — Record Payment

**File:** `Features/Payment/RecordPaymentView.swift`

**Purpose:** Enter an amount, optionally a note, confirm.

### Layout

- Navigation title: "Payment from [name]" (inline).
- **Amount card** (centered):
  - Label: "AMOUNT RECEIVED" (small caps).
  - Big number: 48pt semibold, success color. Tap to focus and edit.
  - Sub-line: "[Name] currently owes X EGP".
- **After-payment preview card**:
  - Label: "AFTER THIS PAYMENT".
  - Line: "[Name] will owe Y EGP".
  - If amount > current balance: show in warning color with "Includes overpayment of Z" — for v1 we allow overpayment (which results in a negative balance — the business owes the salesman); in v2 we may add a confirmation.
- **Note field** (optional): a single-line text field, placeholder "Cash, in person".
- **"Confirm payment"** button: full-width, success-color filled, at the bottom.

### Data

```swift
@Bindable var salesman: Salesman
@State private var amount: Decimal = 0
@State private var note: String = ""

private var projectedBalance: Decimal {
    salesman.balance - amount
}
```

### States

- **Amount == 0:** confirm disabled.
- **Amount > 0, ≤ balance:** confirm enabled (success).
- **Amount > balance:** confirm enabled, warning visible. Tapping shows an alert: "This is more than [Name] currently owes. Record an overpayment?" Yes → proceed.

### Interactions

- Numeric input via a decimal keypad. Use `TextField` with `.keyboardType(.decimalPad)`.
- Confirm → `LedgerService.recordPayment(...)`, pop back to `SalesmanDetailView`. Haptic success feedback (`UINotificationFeedbackGenerator.notificationOccurred(.success)`).

---

## Screen 5 — Products List (Inventory)

**File:** `Features/Products/ProductsListView.swift`

**Purpose:** See all products at a glance with current stock. Add or edit products.

### Layout

- Navigation title: "Products" (large title).
- Header label: "HANY DISTRIBUTION" (small caps).
- **Summary card:** total inventory value (sum of cost price × current stock across all active products) + product count.
- **List** of products, alphabetical:
  - Name (medium weight).
  - Sub-line: "Cost X · Sell Y".
  - Right side: **stock pill**:
    - Healthy (stock > threshold, or no threshold and stock > 0): success-bg, success ink, "X in stock".
    - Low (threshold set and stock <= threshold): warning-bg, warning ink, "X in stock".
    - Out (stock <= 0): danger-bg, danger ink, "0 in stock".
- Toolbar: "+" button → present `ProductEditorView()` as a sheet to add a new product.

### Data

```swift
@Query(
    filter: #Predicate<Product> { $0.deletedAt == nil },
    sort: \Product.name
)
private var products: [Product]

private var inventoryValue: Decimal {
    products.reduce(Decimal(0)) { sum, p in
        sum + (Decimal(p.currentStock) * p.costPrice)
    }
}
```

### States

- **Empty (no products):** centered placeholder with `Image(systemName: "shippingbox")` and copy: *"Add your first product to start tracking inventory."* + an "Add Product" button.
- **Loaded:** as designed.

### Interactions

- Tap a product → present `ProductEditorView(product:)` as a sheet (edit mode).
- Long-press a product → action sheet: "Edit" / "Delete" (soft delete; disabled if any transaction items exist).

---

## Screen 6 — Product Picker (sheet)

**File:** `Features/Distribution/ProductPickerView.swift`

**Purpose:** Modal product selector used inside `GiveProductsView`. Shows the catalog with stock visible per row. Out-of-stock items disabled.

### Layout

- Navigation title: "Pick product" (inline).
- Leading toolbar: "Cancel" — dismiss with no selection.
- Top: search bar (filters list by `name.localizedCaseInsensitiveContains`).
- List of products, alphabetical:
  - Name + sub-line "X EGP · Y in stock".
  - Right: "+" glyph in accent color.
- Out-of-stock products: opacity 0.4, not tappable, no "+" glyph.

### Data

```swift
@Query(
    filter: #Predicate<Product> { $0.deletedAt == nil },
    sort: \Product.name
)
private var products: [Product]

@State private var searchText: String = ""

private var filtered: [Product] {
    guard !searchText.isEmpty else { return products }
    return products.filter {
        $0.name.localizedCaseInsensitiveContains(searchText)
    }
}
```

### Interactions

- Tap an in-stock product → dismiss the sheet and return the selected product to the caller via a binding or closure.
- Swipe down or "Cancel" → dismiss with no selection.

### API to the caller

The picker is a modal. Use a callback closure pattern:

```swift
struct ProductPickerView: View {
    let onSelect: (Product) -> Void
    @Environment(\.dismiss) private var dismiss
    // ...
}
```

The caller (`GiveProductsView`) presents it as:

```swift
.sheet(isPresented: $showingPicker) {
    NavigationStack {
        ProductPickerView { product in
            lines.append(LineDraft(product: product, quantity: 1))
            showingPicker = false
        }
    }
}
```

---

## Cross-cutting

### Number formatting

Use a shared formatter:

```swift
enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0  // EGP traditionally shown without decimals at this scale
        return f
    }()

    static func string(_ amount: Decimal) -> String {
        shared.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
```

Display amounts as: `CurrencyFormatter.string(salesman.balance)` followed by "EGP" as a separate, smaller, muted label.

### Dates

```swift
enum DateFormatting {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
```

### Empty states

Every screen with a list has an explicit empty state. No "blank screen" states. Use `Image(systemName:)` glyphs + a heading + a one-line copy + an action button if applicable.

### Haptics

- Success on payment confirm: `UINotificationFeedbackGenerator().notificationOccurred(.success)`.
- Light tap on stepper increment.
- Warning on overpayment alert: `UINotificationFeedbackGenerator().notificationOccurred(.warning)`.

### Accessibility

- All buttons have accessibility labels.
- Large balance numbers use `.accessibilityLabel("Ahmed owes 11,000 Egyptian pounds")`.
- All interactive controls have minimum 44x44 tap targets.
- Test with VoiceOver before each step is marked done.

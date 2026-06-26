# Build Plan

This document is the ordered task list. Work through it sequentially. Each step is a self-contained unit of work — usually 30 minutes to 2 hours. After each step, the project must compile and the verification scenario must pass before moving on.

## How to use this plan

- Tackle exactly one step at a time. Do not jump ahead.
- Before starting a step, read its **Goal**, **Files**, and **Acceptance criteria**.
- After finishing a step, walk through the **Verification** scenario manually. If it passes, the step is done. If not, fix before continuing.
- If a step takes more than 2 hours, stop and re-scope.

---

## Step 1 — Project setup

**Goal:** Create the Xcode project with the right deployment target, folder structure, and a working "hello world" SwiftUI shell.

**Files:**

- Create the Xcode project: `DistributorApp` (iOS App template, SwiftUI, Swift, Storage: SwiftData, host language: Swift).
- Set deployment target to **iOS 17.0**.
- Set bundle identifier (Mustafa picks).
- Set the device family to **iPhone only** (no iPad for v1).
- Create folders matching the structure in `CLAUDE.md`:
  - `App/`, `Models/`, `Features/`, `Components/`, `Theme/`, `Utilities/`
- Move the generated `DistributorAppApp.swift` into `App/`.

**Acceptance criteria:**

- Project compiles.
- App launches in the simulator to a blank screen.
- Deployment target is iOS 17.0.
- Folder structure is in place (even if mostly empty).

**Verification:** Run in simulator. App launches without crash. That's it.

---

## Step 2 — Theme & design tokens

**Goal:** Define colors, typography, and spacing tokens.

**Files to create:**

- `Theme/Color+Theme.swift` — extension on `Color` with all tokens from `CLAUDE.md`.
- `Theme/Typography.swift` — `Font` extensions for "hero" style and any other custom sizes.
- `Theme/Spacing.swift` — `enum Spacing` and `enum Radius` with constants.

**Example shape for `Color+Theme.swift`:**

```swift
import SwiftUI

extension Color {
    enum theme {
        static let background = Color(hex: 0xF1EFE8)
        static let surface = Color(hex: 0xFFFFFF)
        static let surface2 = Color(hex: 0xF7F6F1)
        static let border = Color(hex: 0xE3E0D6)
        static let border2 = Color(hex: 0xD0CCBF)
        static let ink = Color(hex: 0x1F1F1D)
        static let ink2 = Color(hex: 0x5A5851)
        static let ink3 = Color(hex: 0x8A877E)
        static let accent = Color(hex: 0x2C5F8D)
        static let accentBg = Color(hex: 0xE8EFF5)
        static let success = Color(hex: 0x2D7A4C)
        static let successBg = Color(hex: 0xE8F3EB)
        static let warning = Color(hex: 0x9A6618)
        static let warningBg = Color(hex: 0xFAF0DB)
        static let danger = Color(hex: 0xA32D2D)
        static let dangerBg = Color(hex: 0xFBEAEA)
    }

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

**Acceptance criteria:**

- All tokens compile.
- A simple preview view shows each color swatch correctly (build a quick `ThemePreview` view in `#Preview`).

**Verification:** Add a temporary view that lists every color as a labeled row. Confirm in the preview that the colors match the mockup. Delete the preview view when done.

---

## Step 3 — SwiftData models

**Goal:** Implement the four `@Model` classes from `SCHEMA.md` and wire them into the app's `ModelContainer`.

**Files to create:**

- `Models/Salesman.swift`
- `Models/Product.swift`
- `Models/Transaction.swift`
- `Models/TransactionItem.swift`
- `Models/TransactionType.swift`
- `Models/StockStatus.swift`

**Files to modify:**

- `App/DistributorAppApp.swift` — set up the `ModelContainer` with all four models.

```swift
import SwiftUI
import SwiftData

@main
struct DistributorAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Salesman.self,
            Product.self,
            Transaction.self,
            TransactionItem.self,
        ])
    }
}
```

Create a stub `RootView` in `App/RootView.swift` — empty for now.

**Acceptance criteria:**

- All models compile.
- `ModelContainer` initializes without crashing on app launch.
- All properties and computed properties from `SCHEMA.md` are present.

**Verification:** App launches. No crash. The actual model behavior is tested in step 4 when we seed data.

---

## Step 4 — Seed data & ledger service

**Goal:** Implement the `LedgerService` operations and a debug seed that populates realistic test data.

**Files to create:**

- `Utilities/LedgerService.swift` — `recordDistribution`, `recordPayment`, `reverse` static functions per `SCHEMA.md`.
- `Utilities/PreviewSeed.swift` — populates the model container with 5 salesmen, 8 products, and 20-30 transactions.

**Files to modify:**

- `App/DistributorAppApp.swift` — under `#if DEBUG`, seed the container on first launch (check if `Salesman` count is 0, then seed).

**`PreviewSeed` structure:**

```swift
import Foundation
import SwiftData

enum PreviewSeed {
    @MainActor
    static func populateIfEmpty(_ context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Salesman>())
        guard existing.isEmpty else { return }

        // Products
        let tv = Product(name: "TV", costPrice: 7000, sellingPrice: 10000, openingStock: 50)
        let soundbar = Product(name: "Soundbar", costPrice: 1400, sellingPrice: 2000, openingStock: 30)
        // ... etc

        [tv, soundbar, /* ... */].forEach { context.insert($0) }

        // Salesmen
        let ahmed = Salesman(name: "Ahmed", phone: "+201001234567")
        let mahmoud = Salesman(name: "Mahmoud")
        // ... etc

        [ahmed, mahmoud, /* ... */].forEach { context.insert($0) }

        try context.save()

        // Transactions across recent dates
        try LedgerService.recordDistribution(
            to: ahmed,
            items: [(tv, 2), (soundbar, 3)],
            in: context
        )
        // ... etc
    }
}
```

**Acceptance criteria:**

- App launches with 5 salesmen, 8 products, and a realistic mix of transactions visible in the model container.
- `LedgerService.recordDistribution` correctly creates a transaction, line items, and updates `salesman.balance` (computed).
- `LedgerService.recordPayment` reduces the balance.
- `LedgerService.reverse` creates a reversing transaction and the original's `balance` contribution is excluded.

**Verification:** Add a temporary debug view that lists every salesman with their balance and every product with current stock. Confirm:

- Ahmed has a non-zero balance after the seed.
- TV stock reflects the seeded distributions (e.g., 50 - distributed = current).
- Reversing a seeded transaction in code changes the balance accordingly.

Delete the debug view when done.

---

## Step 5 — Root tab structure

**Goal:** Two-tab navigation: Salesmen and Products.

**Files to create/modify:**

- `App/RootView.swift` — `TabView` with two tabs, each a `NavigationStack` containing a placeholder for now.

```swift
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SalesmenListView()  // stub
            }
            .tabItem {
                Label("Salesmen", systemImage: "person.2.fill")
            }

            NavigationStack {
                ProductsListView()  // stub
            }
            .tabItem {
                Label("Products", systemImage: "shippingbox.fill")
            }
        }
        .tint(.theme.accent)
    }
}
```

- `Features/Salesmen/SalesmenListView.swift` — stub view with `Text("Salesmen")`.
- `Features/Products/ProductsListView.swift` — stub view with `Text("Products")`.

**Acceptance criteria:**

- App opens to the Salesmen tab.
- Tab bar shows both tabs with correct labels and icons.
- Tapping the Products tab switches to that stub.
- Active tab uses the accent color.

**Verification:** Launch. Tap both tabs. They switch correctly.

---

## Step 6 — Salesmen List screen

**Goal:** Implement Screen 1 in full per `SCREENS.md`.

**Files to create/modify:**

- `Features/Salesmen/SalesmenListView.swift` — full implementation.
- `Components/SummaryCard.swift` — reusable summary card component.
- `Components/SalesmanRow.swift` — row component.
- `Components/EmptyStateView.swift` — reusable empty state.

**Acceptance criteria:**

- List shows seeded salesmen, sorted by balance descending in "Owed to you" section.
- "Settled" section appears below if any salesmen have balance == 0, alphabetical, dimmed.
- Summary card shows total outstanding.
- "Last activity" shows in warning color for salesmen idle > 14 days.
- "+" toolbar button is present but can be a no-op for this step (we add the editor in step 11).
- Empty state shows correctly when there are no salesmen (test by temporarily disabling the seed).

**Verification:**

1. Launch the app.
2. The Salesmen tab shows the seeded data laid out per the mockup.
3. The total outstanding equals the sum of all owing balances.
4. A salesman with no transactions in 14+ days has warning-colored "last activity" text.
5. Settled salesmen appear at the bottom, dimmed.

---

## Step 7 — Salesman Detail screen

**Goal:** Implement Screen 2 in full, including the balance hero, action buttons, and activity ledger. Reversal flow can be a placeholder (just a no-op alert) — full reversal happens in step 12.

**Files to create:**

- `Features/Salesmen/SalesmanDetailView.swift`
- `Components/BalanceHeroCard.swift`
- `Components/ActivityRow.swift`

**Files to modify:**

- `Features/Salesmen/SalesmenListView.swift` — make each row a `NavigationLink` to the detail view.

**Acceptance criteria:**

- Tapping a salesman navigates to the detail view.
- Balance hero shows the current balance prominently in accent color.
- Activity list shows all transactions newest first.
- Distributions display as "Gave products" with line items listed underneath.
- Payments display as "Payment received".
- Action buttons "Gave products" and "Record payment" exist (can be placeholders — they navigate to stub screens for now).

**Verification:**

1. From the Salesmen list, tap Ahmed.
2. The detail view shows Ahmed's balance and his full transaction history.
3. The history matches what was seeded.
4. Both action buttons are visible and tappable (even if they go to a blank view).

---

## Step 8 — Give Products flow

**Goal:** Implement Screen 3 (the cart) and Screen 6 (the picker sheet).

**Files to create:**

- `Features/Distribution/GiveProductsView.swift`
- `Features/Distribution/ProductPickerView.swift`
- `Features/Distribution/LineDraft.swift`
- `Components/Stepper.swift` (if the standard SwiftUI stepper doesn't visually match the mockup — likely it doesn't; build a custom one).

**Files to modify:**

- `Features/Salesmen/SalesmanDetailView.swift` — wire "Gave products" button to push `GiveProductsView(salesman:)`.

**Acceptance criteria:**

- Tapping "Gave products" from a salesman's detail navigates to the cart.
- Tapping "+ Add another product" presents the picker sheet.
- Selecting a product from the picker adds a line to the cart with quantity 1.
- The stepper increments and decrements quantity. Decrementing to 0 removes the line.
- The footer total reflects the cart in real time.
- "Confirm" is disabled while the cart is empty.
- Tapping "Confirm" calls `LedgerService.recordDistribution`, dismisses back to the salesman detail, and the new transaction appears at the top of the activity list.
- The cart respects the unsaved-changes back behavior (alert if non-empty).
- Out-of-stock products in the picker are visibly disabled.

**Verification:**

1. From Ahmed's detail, tap "Gave products".
2. Tap "+ Add another product". Picker opens.
3. Select TV. Cart now has TV × 1, line total 10,000.
4. Tap +. Quantity becomes 2, line total 20,000.
5. Add Soundbar × 3. Cart total = 26,000.
6. Tap Confirm. App returns to Ahmed's detail. New transaction at top of list. Balance has increased by 26,000.
7. Go to Products tab. TV stock reduced by 2, Soundbar by 3.

---

## Step 9 — Record Payment screen

**Goal:** Implement Screen 4.

**Files to create:**

- `Features/Payment/RecordPaymentView.swift`

**Files to modify:**

- `Features/Salesmen/SalesmanDetailView.swift` — wire "Record payment" button.

**Acceptance criteria:**

- Big number input with decimal pad keyboard.
- Live "after this payment" preview updates as the user types.
- Overpayment shows the warning and confirmation alert.
- Optional note field accepts text.
- Confirm calls `LedgerService.recordPayment`, dismisses, new payment appears in activity, balance decreases.
- Haptic success feedback on confirm.

**Verification:**

1. From Ahmed's detail, tap "Record payment".
2. Enter 5,000. The "after" preview shows the projected balance.
3. Tap Confirm. App returns to Ahmed's detail. Balance has decreased by 5,000. New payment is at the top of the activity list.
4. Try an overpayment (amount > balance). Confirmation alert appears. Accept it. Balance goes negative (or zero, depending on amount).

---

## Step 10 — Products List screen

**Goal:** Implement Screen 5.

**Files to create:**

- `Components/StockPill.swift`

**Files to modify:**

- `Features/Products/ProductsListView.swift` — full implementation.

**Acceptance criteria:**

- All seeded products appear, alphabetical.
- Each row shows name, cost/sell prices, and a color-coded stock pill.
- Summary card shows total inventory value.
- Empty state when no products exist.
- "+" toolbar button present (we add the editor in step 11).

**Verification:** Open the Products tab. All products show with their current stock and appropriate pill color (healthy/low/out).

---

## Step 11 — Editors (Add/Edit Salesman, Add/Edit Product)

**Goal:** Implement the two editor sheets so the owner can add real data and edit existing entries.

**Files to create:**

- `Features/Salesmen/SalesmanEditorView.swift`
- `Features/Products/ProductEditorView.swift`

**Files to modify:**

- `Features/Salesmen/SalesmenListView.swift` — wire "+" toolbar button.
- `Features/Salesmen/SalesmanDetailView.swift` — wire "Edit" toolbar button.
- `Features/Products/ProductsListView.swift` — wire "+" toolbar button and row taps.

**Editor design:**

Use a SwiftUI `Form` with sections. Each editor accepts an optional model — if nil, it creates a new one; if set, it edits.

**Salesman editor fields:**

- Name (required).
- Phone (optional).
- Notes (optional, multiline).
- If editing: a "Delete" button (soft delete; disabled if the salesman has any transactions).

**Product editor fields:**

- Name (required).
- Cost price (required, decimal).
- Selling price (required, decimal).
- Opening stock (required, integer, defaults to 0 for new products).
- Reorder threshold (optional, integer).
- If editing: a "Delete" button (soft delete; disabled if the product has any transaction items).

**Acceptance criteria:**

- New salesman/product can be created from the "+" button and appears in the list.
- Existing salesman/product can be edited and changes persist.
- Soft delete works: deleted entities disappear from the lists but their history remains (try deleting Ahmed — confirm his transactions still exist in the model but he's not in the list).

**Verification:**

1. Add a new salesman "Test User". They appear at the bottom of the settled section (balance 0).
2. Edit them — change the name. Confirm it updates in the list.
3. Soft-delete them. They disappear from the list.
4. Same flow for products.

---

## Step 12 — Reversal flow

**Goal:** Wire the activity-row tap action to enable reversing a transaction.

**Files to modify:**

- `Features/Salesmen/SalesmanDetailView.swift` — tap on activity row → action sheet with "Reverse this transaction" option.
- Components/ActivityRow.swift — show strikethrough style when `transaction.isReversed`.

**Acceptance criteria:**

- Tapping any non-reversed transaction shows an action sheet with "Reverse" (destructive) and "Cancel".
- Confirming reversal calls `LedgerService.reverse`, appends a reversal entry to the activity list, and updates the salesman's balance.
- The original transaction now appears with strikethrough and reduced opacity.
- Reversed transactions cannot be reversed again (the option is hidden in their action sheet).

**Verification:**

1. Open Ahmed's detail.
2. Find the original distribution from the seed.
3. Tap it → action sheet → tap "Reverse".
4. Balance updates. The original now shows strikethrough. A new reversal entry appears at the top.
5. Tapping the reversed entry no longer offers "Reverse" again.

---

## Step 13 — Polish pass

**Goal:** Final visual and behavioral polish before showing the app to the customer.

**Tasks:**

- Empty states on all screens use the right glyph and copy.
- Haptics in place: success on payment confirm, light tap on stepper.
- All amounts go through `CurrencyFormatter`.
- All dates go through `DateFormatting`.
- No hardcoded strings — every label uses `String(localized:)`.
- Add an app icon (Mustafa provides; placeholder is fine for first demo).
- Add a launch screen (single-color background, app name).
- Verify all 6 screens against `docs/mockups.html` side-by-side. Fix any drift.
- Run through the full happy path: open app → tap salesman → give products → confirm → record payment → confirm → reverse a transaction → soft-delete a salesman → all works.
- Run the same path with VoiceOver enabled. Fix any unlabeled controls.

**Acceptance criteria:**

- Zero warnings in the build log.
- All localized strings registered in `Localizable.strings` (English only for now).
- Manual happy-path test passes end to end.
- No force-unwraps in the codebase (`grep -r "!\$" --include "*.swift"` returns nothing meaningful).

---

## Step 14 — Arabic localization

**Goal:** Add Arabic translations and ensure RTL layout works.

**Tasks:**

- Add Arabic as a supported language in the project.
- Translate every key in `Localizable.strings` to Arabic.
- Switch the simulator to Arabic and walk through every screen. Fix any layout assumption that breaks in RTL.
- Verify number display: Arabic-Indic digits should appear (depends on locale formatter — confirm with `CurrencyFormatter`).
- Verify navigation back arrows mirror correctly (SwiftUI does this automatically for `NavigationStack` if you don't override).

**Acceptance criteria:**

- Switching the device language to Arabic flips the layout to RTL with no broken alignment.
- All visible strings appear in Arabic.

**Verification:** Simulator → Settings → General → Language & Region → Arabic. Re-launch app. Every screen reads right-to-left. Every label is translated.

---

## Step 15 — Demo to the customer

This is not code. This is the step that matters more than any of the others.

**Tasks:**

- Build a TestFlight build (or use a USB-tethered install).
- Take the device to the owner's shop.
- Hand him the device. Say nothing. Watch what he does.
- After 10 minutes of him exploring, ask: *"If I left you with this for a month, would you use it instead of your notebook?"*
- Then ask: *"Would you pay [Mustafa's price] per month for it?"*

**Acceptance criteria:** A yes to both questions. If yes, you've validated a paying product and v2 (with backend, sync, multi-tenant) is justified. If no, the prompts from his hesitation tell you exactly what's missing — fix that, not whatever you were planning to build next.

---

## After v1

Explicitly out of scope until v2 is justified by customer payment:

- Backend / cloud sync
- Authentication
- Multi-warehouse, multi-tenant
- Reports / exports / PDF
- Charts and dashboards
- Salesman-side accounts
- Receipt SMS confirmations
- Push notifications

When v2 is justified, the first file to update is `CLAUDE.md` with the new scope. Then write a new build plan for v2.

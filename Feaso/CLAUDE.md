# Distributor App — Project Context

You are helping build an iOS app for a single, validated customer: a small distributor in Egypt who currently tracks salesman debts and product distributions in a paper notebook. The app replaces that notebook.

This file is the entry point. Read it before every task. For deeper detail, see the referenced files in `docs/`.

---

## What we are building

A SwiftUI app that lets one owner (Mustafa's customer) record:

- Which salesmen owe him money, and how much
- Each distribution of products to a salesman (creates debt)
- Each payment a salesman makes (reduces debt)
- Current product stock in his warehouse

The app is **local-only** for v1. No backend, no auth, no sync, no cloud. SwiftData persists everything on device. We will add a backend in v2 if and only if the customer says yes and pays.

## Who we are building for

- One owner, in Egypt, non-technical, opens the app many times per day
- Reads English and Arabic (build English-first, Arabic-ready)
- Cares about one thing above all: *how much does each salesman owe me right now*
- Will abandon the app if a balance is ever wrong and he cannot see why
- Will abandon the app if the UI takes more than 2 taps to do anything frequent

This narrow audience is the constant test for every decision. If a feature would not help this specific owner do his daily work faster than his notebook does, do not build it.

---

## Stack & non-negotiables

- **iOS 17.0+** (minimum deployment target — required for SwiftData)
- **SwiftUI** for all UI
- **SwiftData** for persistence (no Core Data, no SQLite directly)
- **Swift 5.9+**, **Xcode 15.4+**
- **No third-party dependencies** for v1. Standard library + Apple frameworks only. This is non-negotiable.
- **No backend code**. No URLSession, no API clients. Everything is on-device.
- **Decimal** for all money values. Never Double or Float.
- **UUID** for all model IDs.

## Architecture

- **MVVM-lite**. Views observe SwiftData `@Query` directly where possible. Use a thin ViewModel class only when state coordination across views is needed.
- **Feature-based folder structure**, not type-based (no top-level `Views/` and `Models/` for everything — group by feature).
- **One file per type** (`Salesman.swift`, not a multi-model file).
- **Swift structured concurrency** (`async`/`await`, `Task`) — no completion handlers, no Combine for new code.

## Folder structure

```
DistributorApp/
├── CLAUDE.md
├── docs/
│   ├── SCHEMA.md
│   ├── SCREENS.md
│   ├── BUILD_PLAN.md
│   └── mockups.html
├── DistributorApp/
│   ├── App/
│   │   └── DistributorAppApp.swift
│   ├── Models/
│   │   ├── Salesman.swift
│   │   ├── Product.swift
│   │   ├── Transaction.swift
│   │   ├── TransactionItem.swift
│   │   └── TransactionType.swift
│   ├── Features/
│   │   ├── Salesmen/
│   │   ├── Distribution/
│   │   ├── Payment/
│   │   └── Products/
│   ├── Components/
│   ├── Theme/
│   │   ├── Color+Theme.swift
│   │   ├── Typography.swift
│   │   └── Spacing.swift
│   ├── Utilities/
│   │   ├── CurrencyFormatter.swift
│   │   └── PreviewSeed.swift
│   └── Assets.xcassets
└── DistributorAppTests/
```

When you create a new file, place it according to this structure. If a folder doesn't exist yet, create it.

---

## Coding conventions

### Swift / SwiftUI

- Use `final class` for `@Model` types.
- Prefer value types (`struct`) for everything that isn't a model.
- Use `@Environment(\.modelContext)` to access the SwiftData context, not a singleton.
- Use `@Query` in views to read model data. Don't pass arrays through environment.
- View bodies should be < 100 lines. Extract subviews freely.
- Pure-display subviews go in `Components/`. Feature-specific subviews live next to their parent.
- No force-unwraps. No `try!`. Handle nil explicitly.
- Comment the *why*, not the *what*. Don't comment obvious code.

### Naming

- Views end in `View` (`SalesmenListView`, not `SalesmenList`).
- ViewModels end in `Model` or `ViewModel` (pick one and stay consistent — I'll use `Model`).
- Booleans read as questions (`isEmpty`, `hasUnsavedChanges`).
- Action methods are verbs (`recordPayment()`, not `payment()`).

### Money & numbers

- All monetary values are `Decimal`. Never `Double`.
- All money displayed through `CurrencyFormatter.shared.string(from:)` — never inline `String(format:)`.
- Currency is **EGP** (Egyptian Pound), hardcoded for v1. Localize later.
- Quantities are `Int`.

### Dates

- All timestamps are `Date`. Persisted as native `Date` in SwiftData.
- Display dates through a `DateFormatter` extension — never inline.

### Localization

- All user-facing strings go through `String(localized:)` from day one. No hardcoded literals in views.
- File: `Localizable.strings` (English first, Arabic later in step 13 of the build plan).
- The app must survive RTL layout. Never hardcode `.leading`/`.trailing` assumptions in spacing.

---

## Design tokens

Define these in `Theme/`. Reference the visual mockup in `docs/mockups.html`.

### Colors

Light mode (the only mode supported in v1, but design tokens should accept dark mode hooks later):

| Token              | Hex        | Use                                          |
|--------------------|------------|----------------------------------------------|
| `background`       | `#F1EFE8`  | App background (warm off-white)              |
| `surface`          | `#FFFFFF`  | Cards, list rows                             |
| `surface2`         | `#F7F6F1`  | Subtle elevation (summary cards, footers)    |
| `border`           | `#E3E0D6`  | Hairline dividers                            |
| `border2`          | `#D0CCBF`  | Stronger borders, frame edges                |
| `ink`              | `#1F1F1D`  | Primary text                                 |
| `ink2`             | `#5A5851`  | Secondary text                               |
| `ink3`             | `#8A877E`  | Tertiary text, captions                      |
| `accent`           | `#2C5F8D`  | Primary buttons, links, balance hero         |
| `accentBg`         | `#E8EFF5`  | Accent backgrounds                           |
| `success`          | `#2D7A4C`  | Payments received, healthy stock             |
| `successBg`        | `#E8F3EB`  | Success badges                               |
| `warning`          | `#9A6618`  | Stale activity, low stock                    |
| `warningBg`        | `#FAF0DB`  | Warning badges                               |
| `danger`           | `#A32D2D`  | Out of stock, destructive actions only       |
| `dangerBg`         | `#FBEAEA`  | Danger badges                                |

### Typography

- System font (SF Pro) at all sizes. No custom fonts in v1.
- Weights: regular (400), medium (500), semibold (600). No bold (700).
- Sizes follow Apple's Dynamic Type. Use `.title`, `.headline`, `.body`, `.callout`, `.caption` styles. Custom sizes only for the "hero number" on the salesman detail (use 38pt semibold).

### Spacing

8pt grid. Define constants:
- `Spacing.xs = 4`
- `Spacing.sm = 8`
- `Spacing.md = 12`
- `Spacing.lg = 16`
- `Spacing.xl = 22`
- `Spacing.xxl = 32`

Corner radii:
- `Radius.sm = 8` (chips, small badges)
- `Radius.md = 12` (cards, buttons)
- `Radius.lg = 16` (large cards, hero blocks)
- `Radius.xl = 24` (sheets)

---

## Hard rules — do NOT do these

1. **Do not delete transactions.** Ever. To "undo" a transaction, create a reversing transaction (`type = .adjustment`) with the opposite sign and link it via `reverses` to the original. The original is never modified.
2. **Do not store derived values.** Balance is computed from transactions. Stock is computed from transaction items. Never write a `balance` column or a `stock` column that you update separately.
3. **Do not use `Double` for money.** Always `Decimal`.
4. **Do not use force-unwraps.** No `!`, no `try!`, no `as!`. Use `if let`, `guard let`, `?? defaultValue`, or explicit error handling.
5. **Do not hardcode UI strings.** Always `String(localized: "key")`.
6. **Do not introduce third-party packages.** No SPM dependencies in v1.
7. **Do not write a settings screen.** No settings screen in v1. We have nothing to configure.
8. **Do not add charts, reports, exports, or PDF generation.** These are explicitly v2.
9. **Do not assume internet connectivity.** There is none.
10. **Do not add authentication.** There is one user (the owner) on one device.

---

## How to work in this project

When you receive a task:

1. **Read** the relevant section of `docs/BUILD_PLAN.md`. Tasks are numbered. Confirm which step you're on.
2. **Reference** `docs/SCHEMA.md` for any data model question, and `docs/SCREENS.md` for any UI behavior question.
3. **Stay scoped.** Do not jump ahead. If you finish step N and step N+1 was not requested, stop and ask before continuing.
4. **Build before moving on.** After every change, the project must compile cleanly. If you cannot compile, fix it before adding more code.
5. **Match the conventions above.** When in doubt, look at existing files in the same folder for precedent.
6. **Surface decisions.** If a decision is needed that isn't covered in these docs, ask. Do not invent business rules.

## Definition of done (per step)

A step is "done" when:

- The code compiles in Xcode with no warnings (`xcodebuild` or Cmd-B passes).
- The new UI matches the corresponding screen in `docs/mockups.html` to within reasonable interpretation.
- All new strings are wrapped in `String(localized:)`.
- All new monetary values use `Decimal` and display through `CurrencyFormatter`.
- No new force-unwraps were introduced.
- The previous-step seed data still works (i.e. previous steps did not break).

## How to verify

After each step, the developer (Mustafa) will manually run the app in the simulator and walk through the scenario described in the build plan. If the scenario works, the step is accepted. If not, fix and re-verify.

---

## Companion files

- **`docs/SCHEMA.md`** — full SwiftData model design, relationships, computed properties, rationale.
- **`docs/SCREENS.md`** — every screen with purpose, layout, states, interactions, edge cases.
- **`docs/BUILD_PLAN.md`** — ordered, granular steps. Work through them sequentially.
- **`docs/mockups.html`** — visual reference for every screen.

If a question isn't answered by these files, ask. Do not invent.

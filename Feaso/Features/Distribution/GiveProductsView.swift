import SwiftUI
import SwiftData

struct GiveProductsView: View {
    let salesman: Salesman
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var lines: [LineDraft] = []
    @State private var showingPicker = false
    @State private var showingDiscardAlert = false
    @State private var showingStockWarning = false
    
    private var newTotal: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
    }
    
    private var projectedBalance: Decimal {
        salesman.balance + newTotal
    }
    
    private var hasStockWarnings: Bool {
        lines.contains { $0.exceedsStock }
    }
    
    private var stockWarningMessage: String {
        let warnings = lines.filter { $0.exceedsStock }
        return warnings.map { line in
            String(localized: "\(line.product.name): only \(line.product.currentStock) in stock, cart has \(line.quantity)")
        }.joined(separator: "\n")
    }
    
    private var excludedProductIDs: Set<UUID> {
        Set(lines.map { $0.product.id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            cartList
            footerBar
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Gave to \(salesman.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    if lines.isEmpty {
                        dismiss()
                    } else {
                        showingDiscardAlert = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ProductPickerView(
                    onSelect: { product in
                        lines.append(LineDraft(product: product, quantity: 1))
                    },
                    excludedProductIDs: excludedProductIDs
                )
            }
        }
        .alert(
            String(localized: "Discard Distribution?"),
            isPresented: $showingDiscardAlert
        ) {
            Button(String(localized: "Discard"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "Keep Editing"), role: .cancel) {}
        } message: {
            Text(String(localized: "Items will not be recorded."))
        }
        .alert(
            String(localized: "Stock Warning"),
            isPresented: $showingStockWarning
        ) {
            Button(String(localized: "Proceed Anyway"), role: .destructive) {
                confirmDistribution()
            }
            Button(String(localized: "Go Back"), role: .cancel) {}
        } message: {
            Text(stockWarningMessage)
        }
    }
    
    // MARK: - Cart List
    
    private var cartList: some View {
        List {
            ForEach(lines) { line in
                CartItemCard(
                    line: line,
                    onQuantityChange: { newQuantity in
                        updateQuantity(for: line.id, to: newQuantity)
                    }
                )
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeLineWithID(line.id)
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                    }
                }
            }
            
            addProductButton
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var addProductButton: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text(String(localized: "Add another product"))
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(Color.Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color.Theme.border2)
            )
        }
    }
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        VStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(String(localized: "\(salesman.name) will owe"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink2)
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(projectedBalance))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                        
                        Text(String(localized: "EGP"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                if !lines.isEmpty {
                    Text(String(localized: "Current \(CurrencyFormatter.string(salesman.balance)) + new \(CurrencyFormatter.string(newTotal))"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Button {
                if hasStockWarnings {
                    showingStockWarning = true
                } else {
                    confirmDistribution()
                }
            } label: {
                Text(String(localized: "Confirm"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Theme.accent)
            .disabled(lines.isEmpty)
        }
        .padding(Spacing.lg)
        .background(Color.Theme.surface2)
    }
    
    // MARK: - Actions
    
    private func removeLineWithID(_ id: UUID) {
        lines.removeAll { $0.id == id }
    }
    
    private func updateQuantity(for id: UUID, to newQuantity: Int) {
        if let index = lines.firstIndex(where: { $0.id == id }) {
            lines[index].quantity = newQuantity
        }
    }
    
    private func confirmDistribution() {
        let items = lines.map { ($0.product, $0.quantity) }
        do {
            try LedgerService.recordDistribution(
                to: salesman,
                items: items,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to record distribution: \(error)")
        }
    }
}

// MARK: - Cart Item Card

private struct CartItemCard: View {
    let line: LineDraft
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                QuantityStepperView(
                    quantity: line.quantity,
                    warningThreshold: line.productCurrentStock,
                    onIncrement: { onQuantityChange(line.quantity + 1) },
                    onDecrement: {
                        if line.quantity > 1 {
                            onQuantityChange(line.quantity - 1)
                        }
                    }
                )
                
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(CurrencyFormatter.string(line.lineTotal))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Text(String(localized: "EGP"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(line.productName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
            
                Spacer()
                
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(line.productSellingPrice))
                    Text(String(localized: "EGP"))
                    Text("·")
                    Text(String(localized: "\(line.productCurrentStock) in stock"))
                }
                .font(.caption)
                .foregroundStyle(line.exceedsStock ? Color.Theme.warning : Color.Theme.ink3)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Quantity Stepper View (callback-based)

private struct QuantityStepperView: View {
    let quantity: Int
    let warningThreshold: Int?
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    private var showWarning: Bool {
        guard let threshold = warningThreshold else { return false }
        return quantity > threshold
    }
    
    private func triggerLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                triggerLightHaptic()
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .tint(Color.Theme.ink)
            
            Text("\(quantity)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(showWarning ? Color.Theme.warning : Color.Theme.ink)
                .frame(minWidth: 32)
            
            Button {
                triggerLightHaptic()
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .tint(Color.Theme.ink)
        }
        .background(Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

#Preview {
    NavigationStack {
        GiveProductsView(salesman: Salesman(name: "Ahmed"))
    }
    .modelContainer(for: [Salesman.self, Product.self, Transaction.self, TransactionItem.self])
}

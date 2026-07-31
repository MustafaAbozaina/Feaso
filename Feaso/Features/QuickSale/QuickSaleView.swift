import SwiftUI
import SwiftData

struct QuickSaleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var lines: [QuickSaleLineDraft] = []
    @State private var showingPicker = false
    @State private var showingDiscardAlert = false
    @State private var showingStockWarning = false
    @State private var attachedImage: UIImage?
    @State private var showingAttachmentSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    private var total: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
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
        .navigationTitle(String(localized: "Quick Sale"))
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
                        lines.append(QuickSaleLineDraft(product: product, quantity: 1))
                    },
                    excludedProductIDs: excludedProductIDs
                )
            }
        }
        .alert(
            String(localized: "Discard Sale?"),
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
                confirmSale()
            }
            Button(String(localized: "Go Back"), role: .cancel) {}
        } message: {
            Text(stockWarningMessage)
        }
        .sheet(isPresented: $showingAttachmentSheet) {
            AttachmentSourceSheet(
                isPresented: $showingAttachmentSheet,
                onSelectCamera: {
                    showingCamera = true
                },
                onSelectLibrary: {
                    showingPhotoLibrary = true
                }
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: $attachedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(image: $attachedImage, sourceType: .photoLibrary)
        }
    }
    
    // MARK: - Cart List
    
    private var cartList: some View {
        List {
            // Cash payment indicator
            Section {
                HStack {
                    Image(systemName: "banknote")
                        .foregroundStyle(Color.Theme.success)
                    Text(String(localized: "Cash Sale"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(localized: "Walk-in Customer"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                }
                .padding(.vertical, Spacing.xs)
            }
            .listRowInsets(EdgeInsets(
                top: Spacing.sm,
                leading: Spacing.lg,
                bottom: Spacing.sm,
                trailing: Spacing.lg
            ))
            
            // Cart items
            Section {
                ForEach(lines) { line in
                    QuickSaleCartItemCard(
                        line: line,
                        onQuantityChange: { newQuantity in
                            updateQuantity(for: line.id, to: newQuantity)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeLineWithID(line.id)
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
                }
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
                // Add product button
                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(lines.isEmpty ? String(localized: "Add product") : String(localized: "Add another product"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.accent)
                }
                .listRowInsets(EdgeInsets(
                    top: Spacing.md,
                    leading: Spacing.lg,
                    bottom: Spacing.md,
                    trailing: Spacing.lg
                ))
            }
            
            // Attachment section
            Section {
                AttachmentButton(
                    attachedImage: attachedImage,
                    onTap: {
                        showingAttachmentSheet = true
                    },
                    onRemove: {
                        attachedImage = nil
                    }
                )
            } header: {
                Text(String(localized: "ATTACHMENT (OPTIONAL)"))
            }
            .listRowInsets(EdgeInsets(
                top: Spacing.sm,
                leading: Spacing.lg,
                bottom: Spacing.sm,
                trailing: Spacing.lg
            ))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        VStack(spacing: Spacing.md) {
            // Total
            HStack {
                Text(String(localized: "Total"))
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(CurrencyFormatter.string(total))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Theme.ink)
                    Text(CurrencyFormatter.symbol)
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
            
            // Confirm button
            Button {
                if hasStockWarnings {
                    showingStockWarning = true
                } else {
                    confirmSale()
                }
            } label: {
                Text(String(localized: "Confirm Sale"))
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
    
    private func confirmSale() {
        // Save attachment if present
        var attachmentFileName: String? = nil
        if let image = attachedImage {
            let transactionId = UUID()
            attachmentFileName = ImageAttachmentService.saveImage(image, for: transactionId)
        }
        
        let items = lines.map { ($0.product, $0.quantity) }
        do {
            try LedgerService.recordQuickSale(
                items: items,
                attachmentFileName: attachmentFileName,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to record quick sale: \(error)")
        }
    }
}

// MARK: - Line Draft

private struct QuickSaleLineDraft: Identifiable {
    let id = UUID()
    let product: Product
    var quantity: Int
    
    var unitPrice: Decimal {
        product.cashPrice
    }
    
    var lineTotal: Decimal {
        unitPrice * Decimal(quantity)
    }
    
    var productName: String {
        product.name
    }
    
    var productCurrentStock: Int {
        product.currentStock
    }
    
    var exceedsStock: Bool {
        quantity > product.currentStock
    }
}

// MARK: - Cart Item Card

private struct QuickSaleCartItemCard: View {
    let line: QuickSaleLineDraft
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                QuickSaleQuantityStepperView(
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
                    
                    Text(CurrencyFormatter.symbol)
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
                    Text(CurrencyFormatter.string(line.unitPrice))
                    Text(CurrencyFormatter.symbol)
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

// MARK: - Quantity Stepper View

private struct QuickSaleQuantityStepperView: View {
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
                    .foregroundStyle(quantity > 1 ? Color.Theme.ink : Color.Theme.ink3)
                    .frame(width: 32, height: 32)
            }
            .disabled(quantity <= 1)
            
            Text("\(quantity)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(showWarning ? Color.Theme.warning : Color.Theme.ink)
                .frame(width: 32, height: 32)
            
            Button {
                triggerLightHaptic()
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.Theme.ink)
                    .frame(width: 32, height: 32)
            }
        }
        .background(Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

#Preview {
    NavigationStack {
        QuickSaleView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

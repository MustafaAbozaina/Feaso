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
            String(localized: "\(line.product.name): only \(line.formattedStock) in stock, cart has \(line.formattedQuantity)")
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
                        let initialQuantity = product.unit.defaultStep
                        lines.append(QuickSaleLineDraft(product: product, quantity: initialQuantity))
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
            .padding(Spacing.md)
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .listRowInsets(EdgeInsets(
                top: Spacing.sm,
                leading: Spacing.lg,
                bottom: Spacing.sm,
                trailing: Spacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // Cart items
            ForEach(lines) { line in
                QuickSaleCartItemCard(
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
                        Label(String(localized: "Delete"), systemImage: "trash")
                    }
                }
            }
            
            // Add product button
            addProductButton
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            // Attachment section
            attachmentSection
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
                Text(lines.isEmpty ? String(localized: "Add product") : String(localized: "Add another product"))
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
    
    private var attachmentSection: some View {
        AttachmentButton(
            attachedImage: attachedImage,
            onTap: {
                showingAttachmentSheet = true
            },
            onRemove: {
                attachedImage = nil
            }
        )
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
    
    private func updateQuantity(for id: UUID, to newQuantity: Decimal) {
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
    let productUnit: ProductUnit
    var quantity: Decimal
    
    init(product: Product, quantity: Decimal) {
        self.product = product
        self.productUnit = product.unit
        self.quantity = quantity
    }
    
    var unitPrice: Decimal {
        product.cashPrice
    }
    
    var lineTotal: Decimal {
        unitPrice * quantity
    }
    
    var productName: String {
        product.name
    }
    
    var productCurrentStock: Decimal {
        product.currentStock
    }
    
    var exceedsStock: Bool {
        quantity > product.currentStock
    }
    
    var formattedQuantity: String {
        productUnit.format(quantity)
    }
    
    var formattedStock: String {
        productUnit.formatWithSymbol(productCurrentStock)
    }
}

// MARK: - Cart Item Card

private struct QuickSaleCartItemCard: View {
    let line: QuickSaleLineDraft
    let onQuantityChange: (Decimal) -> Void
    
    @State private var localQuantity: Decimal
    
    init(line: QuickSaleLineDraft, onQuantityChange: @escaping (Decimal) -> Void) {
        self.line = line
        self.onQuantityChange = onQuantityChange
        self._localQuantity = State(initialValue: line.quantity)
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                QuantityStepper(
                    quantity: $localQuantity,
                    unit: line.productUnit,
                    onRemove: {},
                    warningThreshold: line.productCurrentStock
                )
                .onChange(of: localQuantity) { _, newValue in
                    onQuantityChange(newValue)
                }
                
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
                    Text(line.formattedStock)
                    Text(String(localized: "in stock"))
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

#Preview {
    NavigationStack {
        QuickSaleView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

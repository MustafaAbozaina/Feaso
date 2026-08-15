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
                    },
                    onPriceChange: { newPrice in
                        updatePrice(for: line.id, to: newPrice)
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
    
    private func updatePrice(for id: UUID, to newPrice: Decimal?) {
        if let index = lines.firstIndex(where: { $0.id == id }) {
            lines[index].unitPriceOverride = newPrice
        }
    }
    
    private func confirmSale() {
        // Save attachment if present
        var attachmentFileName: String? = nil
        if let image = attachedImage {
            let transactionId = UUID()
            attachmentFileName = ImageAttachmentService.saveImage(image, for: transactionId)
        }
        
        let items = lines.map { (product: $0.product, quantity: $0.quantity, unitPriceOverride: $0.unitPriceOverride) }
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
    
    /// Custom unit price for this line item only. If nil, uses the default product cash price.
    var unitPriceOverride: Decimal?
    
    init(product: Product, quantity: Decimal, unitPriceOverride: Decimal? = nil) {
        self.product = product
        self.productUnit = product.unit
        self.quantity = quantity
        self.unitPriceOverride = unitPriceOverride
    }
    
    /// The default unit price (cash price for quick sales)
    var defaultUnitPrice: Decimal {
        product.cashPrice
    }
    
    /// The actual unit price used for this line (override if set, otherwise default)
    var unitPrice: Decimal {
        unitPriceOverride ?? defaultUnitPrice
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
    
    /// Returns true if a custom price override is set
    var hasCustomPrice: Bool {
        unitPriceOverride != nil
    }
    
    /// The discount percentage (0-100). Positive means discount, negative means markup.
    var discountPercentage: Decimal? {
        guard let override = unitPriceOverride, defaultUnitPrice > 0 else { return nil }
        let discount = ((defaultUnitPrice - override) / defaultUnitPrice) * 100
        return discount
    }
    
    /// Formatted discount text for display
    var discountDisplayText: String? {
        guard let percentage = discountPercentage else { return nil }
        if percentage > 0 {
            return String(localized: "\(NSDecimalNumber(decimal: percentage.rounded(scale: 1)).intValue)% off")
        } else if percentage < 0 {
            let markup = abs(percentage)
            return String(localized: "\(NSDecimalNumber(decimal: markup.rounded(scale: 1)).intValue)% markup")
        }
        return nil
    }
}

// MARK: - Cart Item Card

private struct QuickSaleCartItemCard: View {
    let line: QuickSaleLineDraft
    let onQuantityChange: (Decimal) -> Void
    let onPriceChange: (Decimal?) -> Void
    
    @State private var localQuantity: Decimal
    @State private var showingPriceEditor = false
    
    init(line: QuickSaleLineDraft, onQuantityChange: @escaping (Decimal) -> Void, onPriceChange: @escaping (Decimal?) -> Void) {
        self.line = line
        self.onQuantityChange = onQuantityChange
        self.onPriceChange = onPriceChange
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
                
                // Editable price row
                Button {
                    showingPriceEditor = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(line.unitPrice))
                            .fontWeight(line.hasCustomPrice ? .semibold : .regular)
                            .foregroundStyle(line.hasCustomPrice ? Color.Theme.accent : Color.Theme.ink2)
                        Text(CurrencyFormatter.symbol)
                            .foregroundStyle(Color.Theme.ink3)
                        
                        // Discount badge
                        if let discountText = line.discountDisplayText {
                            Text(discountText)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Theme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.Theme.successBg)
                                .clipShape(Capsule())
                        }
                        
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(Color.Theme.accent)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                
                // Stock info
                HStack(spacing: Spacing.xs) {
                    if line.hasCustomPrice {
                        Text(String(localized: "was \(CurrencyFormatter.string(line.defaultUnitPrice))"))
                            .strikethrough()
                            .foregroundStyle(Color.Theme.ink3)
                        Text("·")
                            .foregroundStyle(Color.Theme.ink3)
                    }
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
        .sheet(isPresented: $showingPriceEditor) {
            QuickSalePriceEditorSheet(
                productName: line.productName,
                defaultPrice: line.defaultUnitPrice,
                currentPrice: line.unitPrice,
                onSave: { newPrice in
                    if newPrice == line.defaultUnitPrice {
                        onPriceChange(nil)
                    } else {
                        onPriceChange(newPrice)
                    }
                },
                onReset: {
                    onPriceChange(nil)
                }
            )
            .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Price Editor Sheet

private struct QuickSalePriceEditorSheet: View {
    let productName: String
    let defaultPrice: Decimal
    let currentPrice: Decimal
    let onSave: (Decimal) -> Void
    let onReset: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var priceText: String = ""
    @FocusState private var isFocused: Bool
    
    private var enteredPrice: Decimal {
        Decimal(string: priceText) ?? currentPrice
    }
    
    private var discountPercentage: Decimal {
        guard defaultPrice > 0 else { return 0 }
        return ((defaultPrice - enteredPrice) / defaultPrice) * 100
    }
    
    private var discountText: String? {
        let percentage = discountPercentage
        if percentage > 0 {
            return String(localized: "\(NSDecimalNumber(decimal: percentage.rounded(scale: 1)).intValue)% discount")
        } else if percentage < 0 {
            let markup = abs(percentage)
            return String(localized: "\(NSDecimalNumber(decimal: markup.rounded(scale: 1)).intValue)% markup")
        }
        return nil
    }
    
    private var isCustomPrice: Bool {
        enteredPrice != defaultPrice
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Product name
                Text(productName)
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                
                // Price input
                VStack(spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        TextField("0", text: $priceText)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(isCustomPrice ? Color.Theme.accent : Color.Theme.ink)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .decimalInput($priceText)
                        
                        Text(CurrencyFormatter.symbol)
                            .font(.title3)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    
                    // Discount/markup indicator
                    if let text = discountText {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: discountPercentage > 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            Text(text)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(discountPercentage > 0 ? Color.Theme.success : Color.Theme.warning)
                    }
                    
                    // Original price reference
                    if isCustomPrice {
                        Text(String(localized: "Original: \(CurrencyFormatter.string(defaultPrice)) \(CurrencyFormatter.symbol)"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: Spacing.sm) {
                    Button {
                        onSave(enteredPrice)
                        dismiss()
                    } label: {
                        Text(String(localized: "Apply Price"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Theme.accent)
                    .disabled(enteredPrice <= 0)
                    
                    if currentPrice != defaultPrice {
                        Button {
                            onReset()
                            dismiss()
                        } label: {
                            Text(String(localized: "Reset to Original"))
                                .font(.subheadline)
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .navigationTitle(String(localized: "Edit Price"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                priceText = "\(currentPrice)"
                isFocused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        QuickSaleView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

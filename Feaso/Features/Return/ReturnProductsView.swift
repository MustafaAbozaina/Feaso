import SwiftUI
import SwiftData

/// Represents a returnable product with its maximum quantity
struct ReturnableProduct: Identifiable {
    let id: UUID
    let product: Product
    let maxQuantity: Int
    
    init(product: Product, maxQuantity: Int) {
        self.id = product.id
        self.product = product
        self.maxQuantity = maxQuantity
    }
}

/// Draft line for return cart
struct ReturnLineDraft: Identifiable {
    let id: UUID
    let product: Product
    var quantity: Int
    let maxQuantity: Int
    /// Outstanding distributed units at their historical prices, captured when
    /// the line is added, so the preview matches what the ledger will record.
    let lots: [PriceLot]

    init(product: Product, quantity: Int, maxQuantity: Int, lots: [PriceLot]) {
        self.id = UUID()
        self.product = product
        self.quantity = quantity
        self.maxQuantity = maxQuantity
        self.lots = lots
    }

    var productName: String { product.name }
    var lineTotal: Decimal { LedgerService.value(of: quantity, from: lots) }
    var unitPriceDisplay: Decimal {
        quantity > 0 ? lineTotal / Decimal(quantity) : product.cashPrice
    }
    var canIncrement: Bool { quantity < maxQuantity }
}

struct ReturnProductsView: View {
    let salesman: Salesman
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var lines: [ReturnLineDraft] = []
    @State private var showingPicker = false
    @State private var showingDiscardAlert = false
    @State private var attachedImage: UIImage?
    @State private var showingAttachmentSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    /// Products that can still be returned (not already in cart)
    private var availableReturnableProducts: [ReturnableProduct] {
        let alreadyInCart = Set(lines.map { $0.product.id })
        return salesman.returnableProducts
            .filter { !alreadyInCart.contains($0.key.id) }
            .map { ReturnableProduct(product: $0.key, maxQuantity: $0.value) }
            .sorted { $0.product.name < $1.product.name }
    }
    
    /// Check if there are any products that can be added to return
    private var hasMoreProductsToReturn: Bool {
        !availableReturnableProducts.isEmpty
    }
    
    private var returnTotal: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
    }
    
    /// Balance after return (debt decreases)
    private var projectedBalance: Decimal {
        salesman.balance - returnTotal
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !salesman.hasReturnableProducts && lines.isEmpty {
                noProductsView
            } else {
                cartList
                footerBar
            }
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Return from \(salesman.name)"))
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
                ReturnableProductPickerView(
                    returnableProducts: availableReturnableProducts,
                    onSelect: { returnableProduct in
                        lines.append(ReturnLineDraft(
                            product: returnableProduct.product,
                            quantity: 1,
                            maxQuantity: returnableProduct.maxQuantity,
                            lots: LedgerService.outstandingLots(
                                for: salesman,
                                product: returnableProduct.product
                            )
                        ))
                    }
                )
            }
        }
        .alert(
            String(localized: "Discard Return?"),
            isPresented: $showingDiscardAlert
        ) {
            Button(String(localized: "Discard"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "Keep Editing"), role: .cancel) {}
        } message: {
            Text(String(localized: "Return will not be recorded."))
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
    
    // MARK: - No Products View
    
    private var noProductsView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.Theme.ink3)
            
            Text(String(localized: "No products to return"))
                .font(.headline)
                .foregroundStyle(Color.Theme.ink)
            
            Text(String(localized: "This salesman hasn't received any products yet, or all products have already been returned."))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Cart List
    
    private var cartList: some View {
        List {
            ForEach(lines) { line in
                ReturnItemCard(
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
            
            if hasMoreProductsToReturn {
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
    
    private var addProductButton: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text(String(localized: "Add product to return"))
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
                            .foregroundStyle(projectedBalance >= 0 ? Color.Theme.ink : Color.Theme.success)
                        
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                if !lines.isEmpty {
                    Text(String(localized: "Current \(CurrencyFormatter.string(salesman.balance)) − return \(CurrencyFormatter.string(returnTotal))"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Button {
                confirmReturn()
            } label: {
                Text(String(localized: "Confirm Return"))
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
            // Ensure quantity doesn't exceed max
            let maxQty = lines[index].maxQuantity
            lines[index].quantity = min(max(1, newQuantity), maxQty)
        }
    }
    
    private func confirmReturn() {
        // Save attachment if present
        var attachmentFileName: String? = nil
        if let image = attachedImage {
            let transactionId = UUID()
            attachmentFileName = ImageAttachmentService.saveImage(image, for: transactionId)
        }
        
        let items = lines.map { ($0.product, $0.quantity) }
        do {
            try LedgerService.recordReturn(
                from: salesman,
                items: items,
                attachmentFileName: attachmentFileName,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to record return: \(error)")
        }
    }
}

// MARK: - Return Item Card

private struct ReturnItemCard: View {
    let line: ReturnLineDraft
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                ReturnQuantityStepperView(
                    quantity: line.quantity,
                    maxQuantity: line.maxQuantity,
                    onIncrement: { 
                        if line.canIncrement {
                            onQuantityChange(line.quantity + 1)
                        }
                    },
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
                        .foregroundStyle(Color.Theme.success)
                    
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
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(line.unitPriceDisplay))
                        Text(CurrencyFormatter.symbol)
                        Text(String(localized: "per unit"))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
                    
                    Text(String(localized: "\(line.maxQuantity) available to return"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Return Quantity Stepper View

private struct ReturnQuantityStepperView: View {
    let quantity: Int
    let maxQuantity: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    private var isAtMax: Bool { quantity >= maxQuantity }
    private var isAtMin: Bool { quantity <= 1 }
    
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(isAtMin ? Color.Theme.ink3 : Color.Theme.ink)
            .disabled(isAtMin)
            
            Text("\(quantity)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Theme.ink)
                .frame(minWidth: 32)
            
            Button {
                triggerLightHaptic()
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .tint(isAtMax ? Color.Theme.ink3 : Color.Theme.ink)
            .disabled(isAtMax)
        }
        .background(Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

// MARK: - Returnable Product Picker View

private struct ReturnableProductPickerView: View {
    let returnableProducts: [ReturnableProduct]
    let onSelect: (ReturnableProduct) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredProducts: [ReturnableProduct] {
        if searchText.isEmpty {
            return returnableProducts
        }
        return returnableProducts.filter {
            $0.product.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredProducts) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(item.product.name)
                                .font(.body)
                                .foregroundStyle(Color.Theme.ink)
                            
                            HStack(spacing: Spacing.xs) {
                                Text(CurrencyFormatter.string(item.product.cashPrice))
                                Text(CurrencyFormatter.symbol)
                            }
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                        }
                        
                        Spacer()
                        
                        Text(String(localized: "\(item.maxQuantity) available"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: String(localized: "Search products"))
        .navigationTitle(String(localized: "Select product to return"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReturnProductsView(salesman: Salesman(name: "Ahmed"))
    }
    .modelContainer(for: [Salesman.self, Product.self, Transaction.self, TransactionItem.self])
}

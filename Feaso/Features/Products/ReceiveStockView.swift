import SwiftUI
import SwiftData

struct ReceiveStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var lines: [StockReceiptLine] = []
    @State private var showingPicker = false
    @State private var showingDiscardAlert = false
    @State private var note: String = ""
    @State private var attachedImage: UIImage?
    @State private var showingAttachmentSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    private var totalValue: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
    }
    
    private var totalUnits: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }
    
    private var excludedProductIDs: Set<UUID> {
        Set(lines.map { $0.product.id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            stockList
            footerBar
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Receive Stock"))
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
                StockReceiptProductPicker(
                    onSelect: { product in
                        lines.append(StockReceiptLine(product: product, quantity: 1))
                    },
                    excludedProductIDs: excludedProductIDs
                )
            }
        }
        .alert(
            String(localized: "Discard Stock Receipt?"),
            isPresented: $showingDiscardAlert
        ) {
            Button(String(localized: "Discard"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "Keep Editing"), role: .cancel) {}
        } message: {
            Text(String(localized: "Items will not be recorded."))
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
    
    // MARK: - Stock List
    
    private var stockList: some View {
        List {
            ForEach(lines) { line in
                StockReceiptItemCard(
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
            
            noteSection
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
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
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "NOTE (OPTIONAL)"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            TextField(
                String(localized: "Supplier, invoice number, etc."),
                text: $note,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .padding(Spacing.md)
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
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
    
    private var addProductButton: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text(String(localized: "Add product"))
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
                    Text(String(localized: "Total Value"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink2)
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(totalValue))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                        
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                if !lines.isEmpty {
                    Text(String(localized: "\(totalUnits) units across \(lines.count) products"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Button {
                confirmStockReceipt()
            } label: {
                Text(String(localized: "Confirm Receipt"))
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
    
    private func confirmStockReceipt() {
        // Save attachment if present
        var attachmentFileName: String? = nil
        if let image = attachedImage {
            let transactionId = UUID()
            attachmentFileName = ImageAttachmentService.saveImage(image, for: transactionId)
        }
        
        let items = lines.map { ($0.product, $0.quantity) }
        do {
            try LedgerService.recordStockReceipt(
                items: items,
                note: note.isEmpty ? nil : note,
                attachmentFileName: attachmentFileName,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to record stock receipt: \(error)")
        }
    }
}

// MARK: - Stock Receipt Line

struct StockReceiptLine: Identifiable {
    let id = UUID()
    let product: Product
    let productName: String
    let productCostPrice: Decimal
    let currentStock: Int
    var quantity: Int
    
    init(product: Product, quantity: Int) {
        self.product = product
        self.productName = product.name
        self.productCostPrice = product.costPrice
        self.currentStock = product.currentStock
        self.quantity = quantity
    }
    
    var lineTotal: Decimal {
        Decimal(quantity) * productCostPrice
    }
}

// MARK: - Stock Receipt Item Card

private struct StockReceiptItemCard: View {
    let line: StockReceiptLine
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                // Quantity stepper
                HStack(spacing: 0) {
                    Button {
                        if line.quantity > 1 {
                            onQuantityChange(line.quantity - 1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Theme.ink)
                    
                    Text("\(line.quantity)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                        .frame(minWidth: 32)
                    
                    Button {
                        onQuantityChange(line.quantity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.Theme.ink)
                }
                .background(Color.Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                
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
                    Text(CurrencyFormatter.string(line.productCostPrice))
                    Text(CurrencyFormatter.symbol)
                    Text(String(localized: "each"))
                    Text("·")
                    Text(String(localized: "\(line.currentStock) in stock"))
                }
                .font(.caption)
                .foregroundStyle(Color.Theme.ink3)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Stock Receipt Product Picker

private struct StockReceiptProductPicker: View {
    let onSelect: (Product) -> Void
    let excludedProductIDs: Set<UUID>
    
    @Environment(\.dismiss) private var dismiss
    
    @Query(
        filter: #Predicate<Product> { $0.deletedAt == nil },
        sort: \Product.name
    )
    private var products: [Product]
    
    @State private var searchText = ""
    
    private var filtered: [Product] {
        let available = products.filter { !excludedProductIDs.contains($0.id) }
        guard !searchText.isEmpty else { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filtered) { product in
                StockReceiptProductRow(product: product)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(product)
                        dismiss()
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .searchable(
            text: $searchText,
            prompt: String(localized: "Search products")
        )
        .navigationTitle(String(localized: "Select Product"))
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

private struct StockReceiptProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                
                HStack(spacing: Spacing.xs) {
                    Text(String(localized: "Cost"))
                    Text(CurrencyFormatter.string(product.costPrice))
                    Text(CurrencyFormatter.symbol)
                    Text("·")
                    Text(String(localized: "\(product.currentStock) in stock"))
                }
                .font(.caption)
                .foregroundStyle(Color.Theme.ink2)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.Theme.accent)
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        ReceiveStockView()
    }
    .modelContainer(for: [Product.self, Transaction.self, TransactionItem.self])
}

import SwiftUI
import SwiftData

struct ProductEditorView: View {
    let product: Product?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var costPriceText: String = ""
    @State private var cashPriceText: String = ""
    @State private var installmentPriceText: String = ""
    @State private var openingStockText: String = ""
    @State private var reorderThresholdText: String = ""
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool {
        product != nil
    }
    
    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
        guard Decimal(string: costPriceText) != nil else { return false }
        // At least one selling price must be provided
        let hasCashPrice = Decimal(string: cashPriceText) != nil && !cashPriceText.isEmpty
        let hasInstallmentPrice = Decimal(string: installmentPriceText) != nil && !installmentPriceText.isEmpty
        guard hasCashPrice || hasInstallmentPrice else { return false }
        guard Int(openingStockText) != nil || openingStockText.isEmpty else { return false }
        return true
    }
    
    private var canDelete: Bool {
        guard let product else { return false }
        return product.transactionItems.isEmpty
    }
    
    private var showInstallmentPriceWarning: Bool {
        guard let cashPrice = Decimal(string: cashPriceText),
              let installmentPrice = Decimal(string: installmentPriceText),
              !cashPriceText.isEmpty,
              !installmentPriceText.isEmpty else {
            return false
        }
        return installmentPrice < cashPrice
    }
    
    init(product: Product? = nil) {
        self.product = product
    }
    
    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Name"), text: $name)
            }
            
            Section {
                HStack {
                    Text(String(localized: "Cost Price"))
                    Spacer()
                    TextField("0", text: $costPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(CurrencyFormatter.symbol)
                        .foregroundStyle(Color.Theme.ink3)
                }
                
                HStack {
                    Text(String(localized: "Cash Price"))
                    Spacer()
                    TextField("0", text: $cashPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(CurrencyFormatter.symbol)
                        .foregroundStyle(Color.Theme.ink3)
                }
                
                HStack {
                    Text(String(localized: "Installment Price"))
                    Spacer()
                    TextField("0", text: $installmentPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(CurrencyFormatter.symbol)
                        .foregroundStyle(Color.Theme.ink3)
                }
            } header: {
                Text(String(localized: "Pricing"))
            } footer: {
                if showInstallmentPriceWarning {
                    Label(
                        String(localized: "Installment price is lower than cash price"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.Theme.warning)
                }
            }
            
            Section {
                HStack {
                    Text(String(localized: "Opening Stock"))
                    Spacer()
                    TextField("0", text: $openingStockText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                
                HStack {
                    Text(String(localized: "Reorder Threshold"))
                    Spacer()
                    TextField(String(localized: "None"), text: $reorderThresholdText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            } header: {
                Text(String(localized: "Inventory"))
            } footer: {
                Text(String(localized: "You'll see a warning when stock falls to or below the threshold."))
            }
            
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Delete Product"))
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                } footer: {
                    if !canDelete {
                        Text(String(localized: "Cannot delete a product that has been distributed."))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(isEditing 
                         ? String(localized: "Edit Product") 
                         : String(localized: "New Product"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let product {
                name = product.name
                costPriceText = "\(product.costPrice)"
                cashPriceText = "\(product.cashPrice)"
                installmentPriceText = "\(product.installmentPrice)"
                openingStockText = "\(product.openingStock)"
                if let threshold = product.reorderThreshold {
                    reorderThresholdText = "\(threshold)"
                }
            }
        }
        .alert(
            String(localized: "Delete Product?"),
            isPresented: $showingDeleteAlert
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                deleteProduct()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This action cannot be undone."))
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard let costPrice = Decimal(string: costPriceText) else { return }
        
        // Parse prices - if one is missing, copy from the other
        let parsedCashPrice = Decimal(string: cashPriceText)
        let parsedInstallmentPrice = Decimal(string: installmentPriceText)
        
        let cashPrice: Decimal
        let installmentPrice: Decimal
        
        if let cash = parsedCashPrice, let installment = parsedInstallmentPrice {
            cashPrice = cash
            installmentPrice = installment
        } else if let cash = parsedCashPrice {
            cashPrice = cash
            installmentPrice = cash  // Default installment to cash price
        } else if let installment = parsedInstallmentPrice {
            cashPrice = installment  // Default cash to installment price
            installmentPrice = installment
        } else {
            return  // Neither provided (shouldn't happen due to canSave check)
        }
        
        let openingStock = Int(openingStockText) ?? 0
        let reorderThreshold = Int(reorderThresholdText)
        
        let productToSync: Product
        
        if let product {
            product.name = trimmedName
            product.costPrice = costPrice
            product.cashPrice = cashPrice
            product.installmentPrice = installmentPrice
            product.openingStock = openingStock
            product.reorderThreshold = reorderThreshold
            productToSync = product
        } else {
            let newProduct = Product(
                name: trimmedName,
                costPrice: costPrice,
                cashPrice: cashPrice,
                installmentPrice: installmentPrice,
                openingStock: openingStock,
                reorderThreshold: reorderThreshold
            )
            modelContext.insert(newProduct)
            productToSync = newProduct
        }
        
        try? modelContext.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(productToSync)
        }
        
        dismiss()
    }
    
    private func deleteProduct() {
        guard let product else { return }
        product.deletedAt = .now
        try? modelContext.save()
        
        // Sync deletion to Firestore
        Task {
            await SyncService.shared.push(product)
        }
        
        dismiss()
    }
}

#Preview("New") {
    NavigationStack {
        ProductEditorView()
    }
    .modelContainer(for: [Product.self])
}

#Preview("Edit") {
    NavigationStack {
        ProductEditorView(product: Product(
            name: "TV",
            costPrice: 7000,
            cashPrice: 10000,
            installmentPrice: 12000,
            openingStock: 50,
            reorderThreshold: 5
        ))
    }
    .modelContainer(for: [Product.self])
}

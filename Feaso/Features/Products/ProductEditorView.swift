import SwiftUI
import SwiftData

struct ProductEditorView: View {
    let product: Product?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var costPriceText: String = ""
    @State private var sellingPriceText: String = ""
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
        guard Decimal(string: sellingPriceText) != nil else { return false }
        guard Int(openingStockText) != nil || openingStockText.isEmpty else { return false }
        return true
    }
    
    private var canDelete: Bool {
        guard let product else { return false }
        return product.transactionItems.isEmpty
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
                    Text(String(localized: "EGP"))
                        .foregroundStyle(Color.Theme.ink3)
                }
                
                HStack {
                    Text(String(localized: "Selling Price"))
                    Spacer()
                    TextField("0", text: $sellingPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(String(localized: "EGP"))
                        .foregroundStyle(Color.Theme.ink3)
                }
            } header: {
                Text(String(localized: "Pricing"))
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
                sellingPriceText = "\(product.sellingPrice)"
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
        guard let costPrice = Decimal(string: costPriceText),
              let sellingPrice = Decimal(string: sellingPriceText) else {
            return
        }
        let openingStock = Int(openingStockText) ?? 0
        let reorderThreshold = Int(reorderThresholdText)
        
        if let product {
            product.name = trimmedName
            product.costPrice = costPrice
            product.sellingPrice = sellingPrice
            product.openingStock = openingStock
            product.reorderThreshold = reorderThreshold
        } else {
            let newProduct = Product(
                name: trimmedName,
                costPrice: costPrice,
                sellingPrice: sellingPrice,
                openingStock: openingStock,
                reorderThreshold: reorderThreshold
            )
            modelContext.insert(newProduct)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteProduct() {
        guard let product else { return }
        product.deletedAt = .now
        try? modelContext.save()
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
            sellingPrice: 10000,
            openingStock: 50,
            reorderThreshold: 5
        ))
    }
    .modelContainer(for: [Product.self])
}

import SwiftUI
import SwiftData

struct ProductPickerView: View {
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
                ProductPickerRow(product: product)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if product.currentStock > 0 {
                            onSelect(product)
                            dismiss()
                        }
                    }
                    .disabled(product.currentStock <= 0)
                    .opacity(product.currentStock <= 0 ? 0.4 : 1.0)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .searchable(
            text: $searchText,
            prompt: String(localized: "Search products")
        )
        .navigationTitle(String(localized: "Pick product"))
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

private struct ProductPickerRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(product.sellingPrice))
                    Text(String(localized: "EGP"))
                    Text("·")
                    Text(String(localized: "\(product.currentStock) in stock"))
                }
                .font(.caption)
                .foregroundStyle(Color.Theme.ink2)
            }
            
            Spacer()
            
            if product.currentStock > 0 {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.Theme.accent)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        ProductPickerView(
            onSelect: { _ in },
            excludedProductIDs: []
        )
    }
    .modelContainer(for: [Product.self, Transaction.self, TransactionItem.self])
}

import SwiftUI
import SwiftData

struct ProductsListView: View {
    @Query(
        filter: #Predicate<Product> { $0.deletedAt == nil },
        sort: \Product.name
    )
    private var products: [Product]
    
    @State private var showingAddSheet = false
    @State private var showingReceiveStock = false
    @State private var selectedProduct: Product?
    
    private var inventoryValue: Decimal {
        products.reduce(Decimal(0)) { sum, product in
            sum + (Decimal(max(0, product.currentStock)) * product.costPrice)
        }
    }
    
    private var productCount: Int {
        products.count
    }
    
    var body: some View {
        Group {
            if products.isEmpty {
                emptyState
            } else {
                productsList
            }
        }
        .navigationTitle(String(localized: "Products"))
        .background(Color.Theme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label(String(localized: "New Product"), systemImage: "shippingbox")
                    }
                    
                    Button {
                        showingReceiveStock = true
                    } label: {
                        Label(String(localized: "Receive Stock"), systemImage: "arrow.down.to.line.compact")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            NavigationStack {
                ProductEditorView(product: product)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                ProductEditorView()
            }
        }
        .sheet(isPresented: $showingReceiveStock) {
            NavigationStack {
                ReceiveStockView()
            }
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            systemImage: "shippingbox",
            title: String(localized: "No Products"),
            message: String(localized: "Add your first product to start tracking inventory."),
            actionTitle: String(localized: "Add Product"),
            action: { showingAddSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var productsList: some View {
        List {
            Section {
                SummaryCard(
                    title: String(localized: "Inventory Value"),
                    amount: inventoryValue,
                    subtitle: String(localized: "\(productCount) products")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            Section {
                ForEach(products) { product in
                    ProductRow(product: product)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProduct = product
                        }
                }
            } header: {
                Text(String(localized: "All Products"))
                    .textCase(.uppercase)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Product Row

private struct ProductRow: View {
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
                    Text("·")
                    Text(String(localized: "Sell"))
                    Text(CurrencyFormatter.string(product.sellingPrice))
                }
                .font(.caption)
                .foregroundStyle(Color.Theme.ink2)
            }
            
            Spacer()
            
            StockPill(stock: product.currentStock, status: product.stockStatus)
        }
        .padding(.vertical, Spacing.sm)
    }
}

#Preview {
    NavigationStack {
        ProductsListView()
    }
    .modelContainer(for: [Product.self, Transaction.self, TransactionItem.self])
}

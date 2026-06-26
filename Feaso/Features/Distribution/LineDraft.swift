import Foundation

struct LineDraft: Identifiable {
    let id = UUID()
    let product: Product
    let productName: String
    let productSellingPrice: Decimal
    let productCurrentStock: Int
    var quantity: Int
    
    init(product: Product, quantity: Int) {
        self.product = product
        self.productName = product.name
        self.productSellingPrice = product.sellingPrice
        self.productCurrentStock = product.currentStock
        self.quantity = quantity
    }
    
    var lineTotal: Decimal {
        Decimal(quantity) * productSellingPrice
    }
    
    var exceedsStock: Bool {
        quantity > productCurrentStock
    }
}

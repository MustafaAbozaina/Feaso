import Foundation

struct LineDraft: Identifiable {
    let id = UUID()
    let product: Product
    let productName: String
    let productCurrentStock: Int
    var quantity: Int
    var paymentType: PaymentType
    
    init(product: Product, quantity: Int, paymentType: PaymentType = .cash) {
        self.product = product
        self.productName = product.name
        self.productCurrentStock = product.currentStock
        self.quantity = quantity
        self.paymentType = paymentType
    }
    
    var unitPrice: Decimal {
        paymentType == .cash ? product.cashPrice : product.installmentPrice
    }
    
    var lineTotal: Decimal {
        Decimal(quantity) * unitPrice
    }
    
    var exceedsStock: Bool {
        quantity > productCurrentStock
    }
}

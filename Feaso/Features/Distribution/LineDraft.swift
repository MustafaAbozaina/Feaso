import Foundation

struct LineDraft: Identifiable {
    let id = UUID()
    let product: Product
    let productName: String
    let productCurrentStock: Decimal
    let productUnit: ProductUnit
    var quantity: Decimal
    var paymentType: PaymentType
    
    init(product: Product, quantity: Decimal, paymentType: PaymentType = .cash) {
        self.product = product
        self.productName = product.name
        self.productCurrentStock = product.currentStock
        self.productUnit = product.unit
        self.quantity = quantity
        self.paymentType = paymentType
    }
    
    var unitPrice: Decimal {
        paymentType == .cash ? product.cashPrice : product.installmentPrice
    }
    
    var lineTotal: Decimal {
        quantity * unitPrice
    }
    
    var exceedsStock: Bool {
        quantity > productCurrentStock
    }
    
    var formattedQuantity: String {
        productUnit.format(quantity)
    }
    
    var formattedStock: String {
        productUnit.formatWithSymbol(productCurrentStock)
    }
}

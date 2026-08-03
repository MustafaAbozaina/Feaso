import SwiftUI

struct StockPill: View {
    let stock: Decimal
    let status: StockStatus
    let unit: ProductUnit
    
    init(stock: Decimal, status: StockStatus, unit: ProductUnit = .piece) {
        self.stock = stock
        self.status = status
        self.unit = unit
    }
    
    private var backgroundColor: Color {
        switch status {
        case .healthy:
            return Color.Theme.successBg
        case .low:
            return Color.Theme.warningBg
        case .outOfStock:
            return Color.Theme.dangerBg
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .healthy:
            return Color.Theme.success
        case .low:
            return Color.Theme.warning
        case .outOfStock:
            return Color.Theme.danger
        }
    }
    
    private var text: String {
        if stock <= 0 {
            return String(localized: "Out of stock")
        }
        return unit.formatWithSymbol(stock) + " " + String(localized: "in stock")
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

#Preview {
    VStack(spacing: 16) {
        StockPill(stock: 50, status: .healthy, unit: .piece)
        StockPill(stock: Decimal(string: "2.5")!, status: .low, unit: .liter)
        StockPill(stock: 0, status: .outOfStock, unit: .kilogram)
    }
    .padding()
}

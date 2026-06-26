import SwiftUI

struct StockPill: View {
    let stock: Int
    let status: StockStatus
    
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
        return String(localized: "\(stock) in stock")
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
        StockPill(stock: 50, status: .healthy)
        StockPill(stock: 3, status: .low)
        StockPill(stock: 0, status: .outOfStock)
    }
    .padding()
}

import SwiftUI

struct ActivityRow: View {
    let transaction: Transaction
    
    private var iconName: String {
        switch transaction.type {
        case .payment:
            return "checkmark"
        case .distribution:
            return "arrow.right"
        case .return:
            return "arrow.uturn.backward"
        case .adjustment:
            return transaction.isReversal ? "arrow.uturn.backward" : "pencil"
        case .stockReceipt:
            return "arrow.down.to.line.compact"
        }
    }
    
    private var iconBackground: Color {
        switch transaction.type {
        case .payment:
            return Color.Theme.successBg
        case .distribution:
            return Color.Theme.accentBg
        case .return, .adjustment:
            return Color.Theme.surface2
        case .stockReceipt:
            return Color.Theme.successBg
        }
    }
    
    private var iconForeground: Color {
        switch transaction.type {
        case .payment:
            return Color.Theme.success
        case .distribution:
            return Color.Theme.accent
        case .return, .adjustment:
            return Color.Theme.ink2
        case .stockReceipt:
            return Color.Theme.success
        }
    }
    
    private var title: String {
        if transaction.isReversal {
            return String(localized: "Reversal")
        }
        switch transaction.type {
        case .payment:
            return String(localized: "Payment received")
        case .distribution:
            return String(localized: "Gave products")
        case .return:
            return String(localized: "Products returned")
        case .adjustment:
            return String(localized: "Adjustment")
        case .stockReceipt:
            return String(localized: "Stock received")
        }
    }
    
    /// Badge text for payment type (only shown for distributions)
    private var paymentTypeBadge: String? {
        guard transaction.type == .distribution,
              let paymentType = transaction.paymentType else {
            return nil
        }
        return paymentType.shortName
    }
    
    /// Number of overdue installments for this transaction
    private var overdueCount: Int {
        transaction.overdueInstallments.count
    }
    
    private var detail: String? {
        if transaction.type == .distribution || transaction.type == .return || transaction.type == .stockReceipt {
            let itemDescriptions = transaction.items.compactMap { item -> String? in
                guard let productName = item.product?.name else { return nil }
                return "\(item.quantity) × \(productName)"
            }
            return itemDescriptions.joined(separator: ", ")
        }
        return transaction.note ?? (transaction.type == .payment ? String(localized: "Cash") : nil)
    }
    
    private var amountColor: Color {
        if transaction.isReversed {
            return Color.Theme.ink3
        }
        return transaction.amount < 0 ? Color.Theme.success : Color.Theme.ink
    }
    
    private var amountPrefix: String {
        transaction.amount < 0 ? "−" : "+"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Circle()
                .fill(iconBackground)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                    
                    if let badge = paymentTypeBadge {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.Theme.accent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.Theme.accentBg)
                            .clipShape(Capsule())
                    }
                    
                    if overdueCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text("\(overdueCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.Theme.warning)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.Theme.warningBg)
                        .clipShape(Capsule())
                    }
                }
                
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 4)
            
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: 2) {
                    Text(amountPrefix)
                    Text(CurrencyFormatter.string(abs(transaction.amount)))
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(amountColor)
                
                Text(DateFormatting.relativeString(from: transaction.occurredAt))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .padding(.vertical, Spacing.sm)
        .opacity(transaction.isReversed ? 0.5 : 1.0)
        .strikethrough(transaction.isReversed, color: Color.Theme.ink3)
    }
}

#Preview {
    List {
        ActivityRow(transaction: {
            let s = Salesman(name: "Test")
            let t = Transaction(type: .distribution, amount: 26000, salesman: s)
            return t
        }())
        
        ActivityRow(transaction: {
            let s = Salesman(name: "Test")
            let t = Transaction(type: .payment, amount: -5000, salesman: s, note: "Partial payment")
            return t
        }())
    }
}

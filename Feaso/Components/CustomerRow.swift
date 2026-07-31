import SwiftUI

struct CustomerRow: View {
    let customer: Customer
    let isSettled: Bool
    
    private var isStale: Bool {
        guard let lastActivity = customer.lastActivityAt else { return false }
        let daysSinceActivity = Calendar.current.dateComponents(
            [.day],
            from: lastActivity,
            to: .now
        ).day ?? 0
        return daysSinceActivity > 14
    }
    
    private var overdueInstallmentsCount: Int {
        customer.transactions
            .filter { $0.reversedBy == nil }
            .flatMap { $0.installments }
            .filter { $0.isOverdue }
            .count
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(customer.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                    
                    if overdueInstallmentsCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text("\(overdueInstallmentsCount)")
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
                
                if let lastActivity = customer.lastActivityAt {
                    Text(DateFormatting.relativeString(from: lastActivity))
                        .font(.caption)
                        .foregroundStyle(isStale ? Color.Theme.warning : Color.Theme.ink3)
                }
            }
            
            Spacer()
            
            if !isSettled {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(customer.balance))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .opacity(isSettled ? 0.6 : 1.0)
    }
}

#Preview {
    List {
        CustomerRow(
            customer: {
                let c = Customer(name: "Ahmed", phone: "+201001234567")
                return c
            }(),
            isSettled: false
        )
        CustomerRow(
            customer: Customer(name: "Khaled"),
            isSettled: true
        )
    }
}

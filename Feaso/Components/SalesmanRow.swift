import SwiftUI

struct SalesmanRow: View {
    let salesman: Salesman
    let isSettled: Bool
    
    private var isStale: Bool {
        guard let lastActivity = salesman.lastActivityAt else { return false }
        let daysSinceActivity = Calendar.current.dateComponents(
            [.day],
            from: lastActivity,
            to: .now
        ).day ?? 0
        return daysSinceActivity > 14
    }
    
    private var overdueInstallmentsCount: Int {
        salesman.transactions
            .filter { $0.reversedBy == nil }
            .flatMap { $0.installments }
            .filter { $0.isOverdue }
            .count
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(salesman.name)
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
                
                if let lastActivity = salesman.lastActivityAt {
                    Text(DateFormatting.relativeString(from: lastActivity))
                        .font(.caption)
                        .foregroundStyle(isStale ? Color.Theme.warning : Color.Theme.ink3)
                }
            }
            
            Spacer()
            
            if !isSettled {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(salesman.balance))
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
        SalesmanRow(
            salesman: {
                let s = Salesman(name: "Ahmed", phone: "+201001234567")
                return s
            }(),
            isSettled: false
        )
        SalesmanRow(
            salesman: Salesman(name: "Khaled"),
            isSettled: true
        )
    }
}

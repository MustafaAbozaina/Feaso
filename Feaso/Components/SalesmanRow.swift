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
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(salesman.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                
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

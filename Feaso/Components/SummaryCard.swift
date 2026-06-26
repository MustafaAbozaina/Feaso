import SwiftUI

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(CurrencyFormatter.string(amount))
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Theme.accent)
                
                Text(String(localized: "EGP"))
                    .font(.callout)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

#Preview {
    SummaryCard(
        title: "Total Outstanding",
        amount: 45000,
        subtitle: "From 4 salesmen"
    )
    .padding()
    .background(Color.Theme.background)
}

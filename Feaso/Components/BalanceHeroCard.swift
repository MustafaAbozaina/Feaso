import SwiftUI

struct BalanceHeroCard: View {
    let balance: Decimal
    let isSettled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(isSettled 
                 ? String(localized: "PAID IN FULL")
                 : String(localized: "CURRENTLY OWES YOU"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(isSettled ? Color.Theme.success : Color.Theme.accent)
            
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(CurrencyFormatter.string(balance))
                    .font(.hero)
                    .foregroundStyle(isSettled ? Color.Theme.success : Color.Theme.accent)
                
                Text(String(localized: "EGP"))
                    .font(.title3)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            if isSettled {
                Text(String(localized: "No outstanding balance"))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(isSettled ? Color.Theme.successBg : Color.Theme.accentBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

#Preview("Owing") {
    BalanceHeroCard(balance: 26000, isSettled: false)
        .padding()
        .background(Color.Theme.background)
}

#Preview("Settled") {
    BalanceHeroCard(balance: 0, isSettled: true)
        .padding()
        .background(Color.Theme.background)
}

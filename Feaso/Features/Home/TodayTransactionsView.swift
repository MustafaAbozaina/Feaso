import SwiftUI
import SwiftData

struct TodayTransactionsView: View {
    @Query(filter: #Predicate<Transaction> { $0.reversedBy == nil })
    private var allTransactions: [Transaction]
    
    private var todayTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allTransactions
            .filter { calendar.isDate($0.occurredAt, inSameDayAs: today) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }
    
    // MARK: - Summary Calculations
    
    private var totalCashReceived: Decimal {
        todayTransactions
            .filter { $0.type == .payment }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var totalCreditGiven: Decimal {
        todayTransactions
            .filter { $0.type == .distribution && $0.paymentType == .installment }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var totalCashSales: Decimal {
        todayTransactions
            .filter { $0.type == .distribution && $0.paymentType == .cash }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var totalReturns: Decimal {
        todayTransactions
            .filter { $0.type == .return }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var salesCount: Int {
        todayTransactions.filter { $0.type == .distribution }.count
    }
    
    private var paymentsCount: Int {
        todayTransactions.filter { $0.type == .payment }.count
    }
    
    var body: some View {
        List {
            // Summary Section
            Section {
                summaryCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Transactions Section
            Section {
                if todayTransactions.isEmpty {
                    emptyState
                } else {
                    ForEach(todayTransactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TodayTransactionRow(transaction: transaction)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Transactions"))
                    .textCase(.uppercase)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Today"))
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: Spacing.md) {
            // Top row: Cash Sales + Credit Given
            HStack(spacing: Spacing.md) {
                SummaryStatCard(
                    title: String(localized: "Cash Sales"),
                    amount: totalCashSales,
                    icon: "banknote",
                    color: Color.Theme.success
                )
                
                SummaryStatCard(
                    title: String(localized: "Credit Given"),
                    amount: totalCreditGiven,
                    icon: "doc.plaintext",
                    color: Color.Theme.accent
                )
            }
            
            // Bottom row: Payments + Returns
            HStack(spacing: Spacing.md) {
                SummaryStatCard(
                    title: String(localized: "Payments"),
                    amount: totalCashReceived,
                    icon: "arrow.down.circle",
                    color: Color.Theme.success,
                    count: paymentsCount
                )
                
                SummaryStatCard(
                    title: String(localized: "Returns"),
                    amount: totalReturns,
                    icon: "arrow.uturn.backward.circle",
                    color: Color.Theme.warning,
                    isNegative: true
                )
            }
        }
        .padding(Spacing.md)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(Color.Theme.ink3)
            Text(String(localized: "No transactions today"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Summary Stat Card

private struct SummaryStatCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color
    var count: Int? = nil
    var isNegative: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink2)
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if isNegative && amount > 0 {
                    Text("-")
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                }
                Text(CurrencyFormatter.string(amount))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Theme.ink)
                Text(CurrencyFormatter.symbol)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Today Transaction Row

private struct TodayTransactionRow: View {
    let transaction: Transaction
    
    private var iconName: String {
        switch transaction.type {
        case .distribution:
            return "arrow.up.right.circle.fill"
        case .payment:
            return "arrow.down.circle.fill"
        case .return:
            return "arrow.uturn.backward.circle.fill"
        case .stockReceipt:
            return "shippingbox.fill"
        case .adjustment:
            return "plusminus.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type {
        case .distribution:
            return transaction.paymentType == .cash ? Color.Theme.success : Color.Theme.accent
        case .payment:
            return Color.Theme.success
        case .return:
            return Color.Theme.warning
        case .stockReceipt:
            return Color.Theme.accent
        case .adjustment:
            return Color.Theme.ink2
        }
    }
    
    private var title: String {
        switch transaction.type {
        case .distribution:
            if let customer = transaction.customer {
                return String(localized: "Sold to \(customer.name)")
            }
            return String(localized: "Distribution")
        case .payment:
            if let customer = transaction.customer {
                return String(localized: "Payment from \(customer.name)")
            }
            return String(localized: "Payment")
        case .return:
            if let customer = transaction.customer {
                return String(localized: "Return from \(customer.name)")
            }
            return String(localized: "Return")
        case .stockReceipt:
            return String(localized: "Stock received")
        case .adjustment:
            return String(localized: "Adjustment")
        }
    }
    
    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        var text = formatter.string(from: transaction.occurredAt)
        
        if transaction.type == .distribution {
            if transaction.paymentType == .cash {
                text += " · " + String(localized: "Cash")
            } else if transaction.paymentType == .installment {
                text += " · " + String(localized: "Installment")
            }
        }
        
        return text
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if transaction.type == .payment || transaction.type == .return {
                        Text("-")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                    }
                    Text(CurrencyFormatter.string(abs(transaction.amount)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption2)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        TodayTransactionsView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

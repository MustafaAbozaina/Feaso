import SwiftUI
import SwiftData

struct MonthlyReportView: View {
    @Query(filter: #Predicate<Transaction> { $0.reversedBy == nil })
    private var allTransactions: [Transaction]
    
    @State private var selectedMonth: Date = Date()
    
    private var calendar: Calendar { Calendar.current }
    
    private var monthTransactions: [Transaction] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? selectedMonth
        
        return allTransactions.filter { transaction in
            transaction.occurredAt >= startOfMonth && transaction.occurredAt <= calendar.date(byAdding: .day, value: 1, to: endOfMonth)!
        }
    }
    
    // MARK: - Summary Calculations
    
    private var totalSales: Decimal {
        monthTransactions
            .filter { $0.type == .distribution }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var cashSales: Decimal {
        monthTransactions
            .filter { $0.type == .distribution && $0.paymentType == .cash }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var creditSales: Decimal {
        monthTransactions
            .filter { $0.type == .distribution && $0.paymentType == .installment }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var totalCollected: Decimal {
        monthTransactions
            .filter { $0.type == .payment }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var totalReturns: Decimal {
        monthTransactions
            .filter { $0.type == .return }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var salesCount: Int {
        monthTransactions.filter { $0.type == .distribution }.count
    }
    
    private var paymentsCount: Int {
        monthTransactions.filter { $0.type == .payment }.count
    }
    
    private var collectionRate: Double {
        guard totalSales > 0 else { return 0 }
        let rate = NSDecimalNumber(decimal: totalCollected / totalSales).doubleValue
        return min(rate, 1.0) // Cap at 100%
    }
    
    // MARK: - Week Breakdown
    
    private var weeklyBreakdown: [(week: Int, sales: Decimal, collected: Decimal)] {
        var weeks: [Int: (sales: Decimal, collected: Decimal)] = [:]
        
        for transaction in monthTransactions {
            let weekOfMonth = calendar.component(.weekOfMonth, from: transaction.occurredAt)
            var current = weeks[weekOfMonth] ?? (sales: 0, collected: 0)
            
            if transaction.type == .distribution {
                current.sales += transaction.amount
            } else if transaction.type == .payment {
                current.collected += abs(transaction.amount)
            }
            
            weeks[weekOfMonth] = current
        }
        
        return weeks.map { (week: $0.key, sales: $0.value.sales, collected: $0.value.collected) }
            .sorted { $0.week < $1.week }
    }
    
    var body: some View {
        List {
            // Month Picker
            Section {
                monthPicker
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Summary Section
            Section {
                summaryCard
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Collection Progress
            Section {
                collectionProgressCard
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Weekly Breakdown
            if !weeklyBreakdown.isEmpty {
                Section {
                    ForEach(weeklyBreakdown, id: \.week) { week in
                        WeekRow(
                            weekNumber: week.week,
                            sales: week.sales,
                            collected: week.collected
                        )
                    }
                } header: {
                    Text(String(localized: "Weekly Breakdown"))
                        .textCase(.uppercase)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Monthly Report"))
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Month Picker
    
    private var monthPicker: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(Color.Theme.accent)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.headline)
                .foregroundStyle(Color.Theme.ink)
            
            Spacer()
            
            Button {
                withAnimation {
                    let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    // Don't go beyond current month
                    if nextMonth <= Date() {
                        selectedMonth = nextMonth
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(isCurrentMonth ? Color.Theme.ink3 : Color.Theme.accent)
            }
            .disabled(isCurrentMonth)
        }
        .padding(Spacing.md)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: Spacing.md) {
            // Total Sales
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "Total Sales"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyFormatter.string(totalSales))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.Theme.ink)
                        Text(CurrencyFormatter.symbol)
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(String(localized: "\(salesCount) sales"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
            
            Divider()
            
            // Cash vs Credit breakdown
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.Theme.success)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "Cash Sales"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text(CurrencyFormatter.string(cashSales))
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.Theme.accent)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "Credit Sales"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text(CurrencyFormatter.string(creditSales))
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.Theme.warning)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "Returns"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text(CurrencyFormatter.string(totalReturns))
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.md)
    }
    
    // MARK: - Collection Progress Card
    
    private var collectionProgressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(String(localized: "Collection Progress"))
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                
                Spacer()
                
                Text("\(Int(collectionRate * 100))%")
                    .font(.headline)
                    .foregroundStyle(Color.Theme.success)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Theme.surface2)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Theme.success)
                        .frame(width: geometry.size.width * collectionRate, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "Collected"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(CurrencyFormatter.string(totalCollected))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.success)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption2)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(String(localized: "\(paymentsCount) payments"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Week Row

private struct WeekRow: View {
    let weekNumber: Int
    let sales: Decimal
    let collected: Decimal
    
    var body: some View {
        HStack {
            Text(String(localized: "Week \(weekNumber)"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(String(localized: "Sales:"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    Text(CurrencyFormatter.string(sales))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                HStack(spacing: Spacing.sm) {
                    Text(String(localized: "Collected:"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    Text(CurrencyFormatter.string(collected))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.success)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        MonthlyReportView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

import SwiftUI
import SwiftData

// MARK: - Date Range Preset

enum DateRangePreset: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case custom
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .today: return String(localized: "Today")
        case .yesterday: return String(localized: "Yesterday")
        case .thisWeek: return String(localized: "This Week")
        case .thisMonth: return String(localized: "This Month")
        case .custom: return String(localized: "Custom")
        }
    }
    
    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
            
        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? now
            return (start, todayStart)
            
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)
            
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return (start, end)
            
        case .custom:
            // Default to today for custom, actual dates managed separately
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
        }
    }
}

// MARK: - Transaction Type Filter

enum TransactionTypeFilter: String, CaseIterable, Identifiable {
    case all
    case sales
    case payments
    case returns
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .all: return String(localized: "All")
        case .sales: return String(localized: "Sales")
        case .payments: return String(localized: "Payments")
        case .returns: return String(localized: "Returns")
        }
    }
    
    func matches(_ type: TransactionType) -> Bool {
        switch self {
        case .all: return true
        case .sales: return type == .distribution
        case .payments: return type == .payment
        case .returns: return type == .return
        }
    }
}

// MARK: - Transactions View

struct TransactionsView: View {
    @Query(filter: #Predicate<Transaction> { $0.reversedBy == nil })
    private var allTransactions: [Transaction]
    
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil })
    private var allProducts: [Product]
    
    // Filter state
    @State private var selectedDatePreset: DateRangePreset = .today
    @State private var customStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate: Date = Date()
    @State private var selectedProduct: Product?
    @State private var selectedTypeFilter: TransactionTypeFilter = .all
    
    // UI state
    @State private var showingDatePicker = false
    @State private var showingProductPicker = false
    
    // Optional: Pre-filter by product when navigating from product detail
    var initialProduct: Product?
    
    init(product: Product? = nil) {
        self.initialProduct = product
    }
    
    // MARK: - Filtered Transactions
    
    private var filteredTransactions: [Transaction] {
        let dateRange: (start: Date, end: Date)
        if selectedDatePreset == .custom {
            let calendar = Calendar.current
            dateRange = (
                calendar.startOfDay(for: customStartDate),
                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
            )
        } else {
            dateRange = selectedDatePreset.dateRange()
        }
        
        return allTransactions
            .filter { transaction in
                // Date filter
                transaction.occurredAt >= dateRange.start && transaction.occurredAt < dateRange.end
            }
            .filter { transaction in
                // Type filter
                selectedTypeFilter.matches(transaction.type)
            }
            .filter { transaction in
                // Product filter
                guard let product = selectedProduct else { return true }
                return transaction.items.contains { $0.product?.id == product.id }
            }
            .sorted { $0.occurredAt > $1.occurredAt }
    }
    
    // MARK: - Summary Calculations
    
    private var totalCashReceived: Decimal {
        filteredTransactions
            .filter { $0.type == .payment }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var totalCreditGiven: Decimal {
        filteredTransactions
            .filter { $0.type == .distribution && $0.paymentType == .installment }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var totalCashSales: Decimal {
        filteredTransactions
            .filter { $0.type == .distribution && $0.paymentType == .cash }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var totalReturns: Decimal {
        filteredTransactions
            .filter { $0.type == .return }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    private var salesCount: Int {
        filteredTransactions.filter { $0.type == .distribution }.count
    }
    
    private var paymentsCount: Int {
        filteredTransactions.filter { $0.type == .payment }.count
    }
    
    private var totalUnits: Decimal {
        filteredTransactions
            .filter { $0.type == .distribution }
            .flatMap { $0.items }
            .reduce(Decimal(0)) { $0 + $1.quantity }
    }
    
    private var uniqueCustomersCount: Int {
        Set(filteredTransactions.compactMap { $0.customer?.id }).count
    }
    
    // MARK: - Navigation Title
    
    private var navigationTitle: String {
        if let product = selectedProduct {
            return product.name
        }
        return selectedDatePreset.localizedName
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Filters Section
            Section {
                filtersView
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Summary Section
            Section {
                summaryCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Transactions Section
            Section {
                if filteredTransactions.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTransactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction, highlightProduct: selectedProduct)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(String(localized: "Transactions"))
                        .textCase(.uppercase)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(filteredTransactions.count)")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingDatePicker) {
            customDatePickerSheet
        }
        .sheet(isPresented: $showingProductPicker) {
            productPickerSheet
        }
        .onAppear {
            if let product = initialProduct, selectedProduct == nil {
                selectedProduct = product
            }
        }
    }
    
    // MARK: - Filters View
    
    private var filtersView: some View {
        VStack(spacing: Spacing.md) {
            // Date Range Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(DateRangePreset.allCases) { preset in
                        FilterChip(
                            title: preset.localizedName,
                            isSelected: selectedDatePreset == preset,
                            action: {
                                if preset == .custom {
                                    showingDatePicker = true
                                }
                                selectedDatePreset = preset
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            
            // Custom date display
            if selectedDatePreset == .custom {
                HStack {
                    Text(customStartDate, style: .date)
                    Text("–")
                    Text(customEndDate, style: .date)
                }
                .font(.caption)
                .foregroundStyle(Color.Theme.ink2)
                .padding(.horizontal, Spacing.md)
            }
            
            // Secondary Filters Row
            HStack(spacing: Spacing.sm) {
                // Product Filter Button
                Button {
                    showingProductPicker = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "shippingbox")
                            .font(.caption)
                        Text(selectedProduct?.name ?? String(localized: "All Products"))
                            .font(.subheadline)
                            .lineLimit(1)
                        if selectedProduct != nil {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.Theme.ink3)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(selectedProduct != nil ? Color.Theme.accentBg : Color.Theme.surface)
                    .foregroundStyle(selectedProduct != nil ? Color.Theme.accent : Color.Theme.ink)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedProduct != nil ? Color.Theme.accent : Color.Theme.border, lineWidth: 1)
                    )
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.01)
                        .onEnded { _ in
                            if selectedProduct != nil {
                                selectedProduct = nil
                            }
                        }
                )
                
                Spacer()
                
                // Type Filter Picker
                Picker("", selection: $selectedTypeFilter) {
                    ForEach(TransactionTypeFilter.allCases) { filter in
                        Text(filter.localizedName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.Theme.accent)
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.vertical, Spacing.md)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: Spacing.md) {
            // Quick Stats Row
            HStack(spacing: Spacing.lg) {
                QuickStat(
                    icon: "person.2",
                    value: "\(uniqueCustomersCount)",
                    label: String(localized: "Customers")
                )
                
                QuickStat(
                    icon: "cube.box",
                    value: "\(totalUnits)",
                    label: String(localized: "Units")
                )
                
                QuickStat(
                    icon: "cart",
                    value: "\(salesCount)",
                    label: String(localized: "Sales")
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            
            Divider()
                .padding(.horizontal, Spacing.md)
            
            // Amounts Grid
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
            Text(String(localized: "No transactions found"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink2)
            if selectedProduct != nil || selectedTypeFilter != .all {
                Text(String(localized: "Try adjusting your filters"))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
    
    // MARK: - Custom Date Picker Sheet
    
    private var customDatePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    String(localized: "Start Date"),
                    selection: $customStartDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                
                DatePicker(
                    String(localized: "End Date"),
                    selection: $customEndDate,
                    in: customStartDate...Date(),
                    displayedComponents: .date
                )
            }
            .navigationTitle(String(localized: "Select Dates"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        showingDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Product Picker Sheet
    
    private var productPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    selectedProduct = nil
                    showingProductPicker = false
                } label: {
                    HStack {
                        Text(String(localized: "All Products"))
                            .foregroundStyle(Color.Theme.ink)
                        Spacer()
                        if selectedProduct == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.Theme.accent)
                        }
                    }
                }
                
                ForEach(allProducts.sorted { $0.name < $1.name }) { product in
                    Button {
                        selectedProduct = product
                        showingProductPicker = false
                    } label: {
                        HStack {
                            Text(product.name)
                                .foregroundStyle(Color.Theme.ink)
                            Spacer()
                            if selectedProduct?.id == product.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.Theme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Select Product"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        showingProductPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .medium : .regular)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.Theme.accent : Color.Theme.surface)
                .foregroundStyle(isSelected ? .white : Color.Theme.ink)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.Theme.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Quick Stat

private struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink2)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.Theme.ink3)
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Transaction Row

private struct TransactionRow: View {
    let transaction: Transaction
    var highlightProduct: Product?
    
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
        
        // Show date if not today
        let calendar = Calendar.current
        if !calendar.isDateInToday(transaction.occurredAt) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            text = dateFormatter.string(from: transaction.occurredAt) + " · " + text
        }
        
        if transaction.type == .distribution {
            if transaction.paymentType == .cash {
                text += " · " + String(localized: "Cash")
            } else if transaction.paymentType == .installment {
                text += " · " + String(localized: "Installment")
            }
        }
        
        // If filtering by product, show quantity
        if let product = highlightProduct,
           let item = transaction.items.first(where: { $0.product?.id == product.id }) {
            text += " · \(item.quantity) " + String(localized: "units")
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
        TransactionsView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

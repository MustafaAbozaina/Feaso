import SwiftUI
import SwiftData

enum CollectionsDateFilter: Equatable {
    case byDate(Date)        // From now to selected date (accumulative)
    case customRange(Date, Date)  // Custom from-to range
    
    var displayName: String {
        switch self {
        case .byDate:
            return String(localized: "By Date")
        case .customRange:
            return String(localized: "Custom Range")
        }
    }
}

enum DatePreset {
    case today
    case tomorrow
    case thisWeek
    case thisMonth
    case custom
}

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allInstallments: [Installment]
    
    @State private var filterMode: Int = 0 // 0 = By Date, 1 = Custom Range
    @State private var selectedPreset: DatePreset = .thisWeek
    @State private var isPresetChange = false // Flag to prevent onChange interference
    @State private var targetDate: Date = WorkWeekManager.endOfWorkWeek()
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showDatePicker = false
    
    // MARK: - Filtered Installments
    
    private var filteredInstallments: [Installment] {
        let validInstallments = allInstallments.filter { installment in
            guard let transaction = installment.transaction else { return false }
            return transaction.reversedBy == nil && !installment.isPaid
        }
        
        let now = Calendar.current.startOfDay(for: Date())
        
        switch filterMode {
        case 0: // By Date - from now to target date (includes overdue)
            let target = Calendar.current.startOfDay(for: targetDate)
            return validInstallments.filter { installment in
                let dueDay = Calendar.current.startOfDay(for: installment.dueDate)
                return dueDay <= target
            }
        case 1: // Custom Range
            let from = Calendar.current.startOfDay(for: fromDate)
            let to = Calendar.current.startOfDay(for: toDate)
            return validInstallments.filter { installment in
                let dueDay = Calendar.current.startOfDay(for: installment.dueDate)
                return dueDay >= from && dueDay <= to
            }
        default:
            return validInstallments
        }
    }
    
    private var overdueInstallments: [Installment] {
        let now = Calendar.current.startOfDay(for: Date())
        return filteredInstallments.filter { installment in
            Calendar.current.startOfDay(for: installment.dueDate) < now
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    private var dueInstallments: [Installment] {
        let now = Calendar.current.startOfDay(for: Date())
        return filteredInstallments.filter { installment in
            Calendar.current.startOfDay(for: installment.dueDate) >= now
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    // MARK: - Grouped by Customer
    
    private func groupByCustomer(_ installments: [Installment]) -> [(Customer, [Installment])] {
        let grouped = Dictionary(grouping: installments) { $0.transaction?.customer }
        return grouped.compactMap { (customer, installments) -> (Customer, [Installment])? in
            guard let customer = customer else { return nil }
            return (customer, installments.sorted { $0.dueDate < $1.dueDate })
        }.sorted { $0.0.name < $1.0.name }
    }
    
    // MARK: - Totals
    
    private var totalExpected: Decimal {
        filteredInstallments.reduce(0) { $0 + $1.amount }
    }
    
    private var overdueTotal: Decimal {
        overdueInstallments.reduce(0) { $0 + $1.amount }
    }
    
    private var dueTotal: Decimal {
        dueInstallments.reduce(0) { $0 + $1.amount }
    }
    
    private var uniqueCustomersCount: Int {
        Set(filteredInstallments.compactMap { $0.transaction?.customer?.id }).count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection
                
                if filteredInstallments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            summaryCard
                            
                            if !overdueInstallments.isEmpty {
                                overdueSection
                            }
                            
                            if !dueInstallments.isEmpty {
                                dueSection
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .refreshable {
                        await SyncService.shared.refresh()
                    }
                }
            }
            .background(Color.Theme.background)
            .navigationTitle(String(localized: "Collections"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        VStack(spacing: Spacing.sm) {
            // Filter mode picker
            Picker("", selection: $filterMode) {
                Text(String(localized: "By Date")).tag(0)
                Text(String(localized: "Custom Range")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            
            // Date selection
            if filterMode == 0 {
                // Quick date presets
                HStack(spacing: Spacing.sm) {
                    QuickDateButton(title: String(localized: "Today"), isSelected: selectedPreset == .today) {
                        isPresetChange = true
                        selectedPreset = .today
                        targetDate = Date()
                    }
                    QuickDateButton(title: String(localized: "Tomorrow"), isSelected: selectedPreset == .tomorrow) {
                        isPresetChange = true
                        selectedPreset = .tomorrow
                        targetDate = tomorrow
                    }
                    QuickDateButton(title: String(localized: "This Week"), isSelected: selectedPreset == .thisWeek) {
                        isPresetChange = true
                        selectedPreset = .thisWeek
                        targetDate = endOfWeek
                    }
                    QuickDateButton(title: String(localized: "This Month"), isSelected: selectedPreset == .thisMonth) {
                        isPresetChange = true
                        selectedPreset = .thisMonth
                        targetDate = endOfMonth
                    }
                }
                .padding(.horizontal, Spacing.md)
                
                // Date picker for custom date
                HStack {
                    Text(String(localized: "Show until"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink2)
                    
                    Spacer()
                    
                    DatePicker("", selection: $targetDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: targetDate) { _, _ in
                            // Only deselect presets if user manually picked a date
                            if isPresetChange {
                                isPresetChange = false
                            } else {
                                selectedPreset = .custom
                            }
                        }
                }
                .padding(.horizontal, Spacing.md)
            } else {
                // Custom Range - from/to date pickers
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(String(localized: "From"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                        DatePicker("", selection: $fromDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(String(localized: "To"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                        DatePicker("", selection: $toDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(Color.Theme.surface)
    }
    
    // MARK: - Date Helpers
    
    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    
    private var endOfWeek: Date {
        WorkWeekManager.endOfWorkWeek()
    }
    
    private var endOfMonth: Date {
        let calendar = Calendar.current
        let today = Date()
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let endOfMonth = calendar.date(byAdding: .day, value: range.count - calendar.component(.day, from: today), to: today) else {
            return today
        }
        return endOfMonth
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: Spacing.sm) {
            Text(String(localized: "Expected Total"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink2)
            
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(CurrencyFormatter.string(totalExpected))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Theme.accent)
                Text(CurrencyFormatter.symbol)
                    .font(.title3)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            Text(String(localized: "from %lld customers · %lld payments", defaultValue: "from \(uniqueCustomersCount) customers · \(filteredInstallments.count) payments"))
                .font(.caption)
                .foregroundStyle(Color.Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    
    // MARK: - Overdue Section
    
    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.Theme.warning)
                Text(String(localized: "Overdue"))
                    .font(.headline)
                    .foregroundStyle(Color.Theme.warning)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(overdueTotal))
                        .fontWeight(.semibold)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                }
                .foregroundStyle(Color.Theme.warning)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            
            // Grouped by customer
            ForEach(groupByCustomer(overdueInstallments), id: \.0.id) { customer, installments in
                CustomerInstallmentsCard(
                    customer: customer,
                    installments: installments,
                    isOverdue: true
                )
            }
        }
        .background(Color.Theme.warningBg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    
    // MARK: - Due Section
    
    private var dueSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.Theme.accent)
                Text(String(localized: "Due"))
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(dueTotal))
                        .fontWeight(.semibold)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                }
                .foregroundStyle(Color.Theme.ink2)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            
            // Grouped by customer
            ForEach(groupByCustomer(dueInstallments), id: \.0.id) { customer, installments in
                CustomerInstallmentsCard(
                    customer: customer,
                    installments: installments,
                    isOverdue: false
                )
            }
        }
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.Theme.success)
            Text(String(localized: "No Pending Collections"))
                .font(.headline)
                .foregroundStyle(Color.Theme.ink2)
            Text(String(localized: "No installments due in this period"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
}

// MARK: - Customer Installments Card (Read-only)

struct CustomerInstallmentsCard: View {
    let customer: Customer
    let installments: [Installment]
    let isOverdue: Bool
    
    private var total: Decimal {
        installments.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationLink(destination: CustomerDetailView(customer: customer)) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Customer header
                HStack {
                    Text(customer.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Spacer()
                    
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(total))
                            .fontWeight(.medium)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    .foregroundStyle(isOverdue ? Color.Theme.warning : Color.Theme.ink2)
                }
                
                // Installment rows
                ForEach(installments) { installment in
                    CollectionInstallmentRow(
                        installment: installment,
                        isOverdue: isOverdue
                    )
                }
            }
            .padding(Spacing.md)
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collection Installment Row (Read-only, no checkbox)

struct CollectionInstallmentRow: View {
    let installment: Installment
    let isOverdue: Bool
    
    private var transactionDescription: String? {
        guard let transaction = installment.transaction else { return nil }
        let itemDescriptions = transaction.items.compactMap { item -> String? in
            guard let productName = item.product?.name else { return nil }
            return "\(item.quantity) × \(productName)"
        }
        return itemDescriptions.isEmpty ? nil : itemDescriptions.joined(separator: ", ")
    }
    
    private var installmentPosition: String {
        guard let transaction = installment.transaction else { return "" }
        return String(localized: "#\(installment.sequenceNumber) of \(transaction.installments.count)")
    }
    
    private var daysInfo: String {
        let now = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: installment.dueDate)
        let days = Calendar.current.dateComponents([.day], from: now, to: due).day ?? 0
        
        if days < 0 {
            return String(localized: "%lld days late", defaultValue: "\(abs(days)) days late")
        } else if days == 0 {
            return String(localized: "Today")
        } else if days == 1 {
            return String(localized: "Tomorrow")
        } else {
            return String(localized: "in %lld days", defaultValue: "in \(days) days")
        }
    }
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Installment indicator icon
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "banknote")
                .font(.subheadline)
                .foregroundStyle(isOverdue ? Color.Theme.warning : Color.Theme.accent)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(installment.amount))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                    Text("·")
                        .foregroundStyle(Color.Theme.ink3)
                    Text(installment.dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? Color.Theme.warning : Color.Theme.ink2)
                    Text("(\(daysInfo))")
                        .font(.caption)
                        .foregroundStyle(isOverdue ? Color.Theme.warning : Color.Theme.ink3)
                }
                
                if let description = transactionDescription {
                    HStack(spacing: Spacing.xs) {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                            .lineLimit(1)
                        Text(installmentPosition)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Quick Date Button

struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.Theme.surface : Color.Theme.accent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? Color.Theme.accent : Color.Theme.accentBg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CollectionsView()
        .modelContainer(for: [Customer.self, Transaction.self, Installment.self, Product.self, TransactionItem.self])
}

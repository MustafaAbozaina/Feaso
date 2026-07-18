import SwiftUI
import SwiftData

enum InstallmentsViewMode: String, CaseIterable {
    case byDueDate
    case byTransaction
    
    var localizedName: String {
        switch self {
        case .byDueDate:
            return String(localized: "By Due Date")
        case .byTransaction:
            return String(localized: "By Transaction")
        }
    }
}

struct InstallmentsListView: View {
    let salesman: Salesman
    let filterTransaction: Transaction?
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allInstallments: [Installment]
    
    @State private var viewMode: InstallmentsViewMode = .byDueDate
    @State private var installmentToConfirm: Installment?
    @State private var showPaymentConfirmation = false
    
    init(salesman: Salesman, filterTransaction: Transaction? = nil) {
        self.salesman = salesman
        self.filterTransaction = filterTransaction
    }
    
    private var relevantInstallments: [Installment] {
        let salesmanInstallments = allInstallments.filter { installment in
            guard let transaction = installment.transaction else { return false }
            return transaction.salesman?.id == salesman.id && transaction.reversedBy == nil
        }
        
        if let filterTransaction = filterTransaction {
            return salesmanInstallments.filter { $0.transaction?.id == filterTransaction.id }
        }
        return salesmanInstallments
    }
    
    private var groupedByDueDate: [(String, [Installment])] {
        let unpaid = relevantInstallments.filter { !$0.isPaid }
        let paid = relevantInstallments.filter { $0.isPaid }.sorted { ($0.paidDate ?? $0.dueDate) > ($1.paidDate ?? $1.dueDate) }
        let sorted = unpaid.sorted { $0.dueDate < $1.dueDate }
        
        var overdue: [Installment] = []
        var thisWeek: [Installment] = []
        var later: [Installment] = []
        
        let now = Date()
        let calendar = Calendar.current
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        
        for installment in sorted {
            if installment.dueDate < now {
                overdue.append(installment)
            } else if installment.dueDate <= weekFromNow {
                thisWeek.append(installment)
            } else {
                later.append(installment)
            }
        }
        
        var result: [(String, [Installment])] = []
        if !overdue.isEmpty {
            result.append((String(localized: "Overdue"), overdue))
        }
        if !thisWeek.isEmpty {
            result.append((String(localized: "This Week"), thisWeek))
        }
        if !later.isEmpty {
            result.append((String(localized: "Later"), later))
        }
        if !paid.isEmpty {
            result.append((String(localized: "Paid"), paid))
        }
        return result
    }
    
    private var groupedByTransaction: [(Transaction, [Installment])] {
        let grouped = Dictionary(grouping: relevantInstallments) { $0.transaction }
        return grouped.compactMap { (transaction, installments) -> (Transaction, [Installment])? in
            guard let transaction = transaction else { return nil }
            let sorted = installments.sorted { $0.sequenceNumber < $1.sequenceNumber }
            return (transaction, sorted)
        }.sorted { $0.0.occurredAt > $1.0.occurredAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filterTransaction == nil {
                viewModeToggle
            }
            
            if relevantInstallments.isEmpty {
                emptyState
            } else {
                installmentsList
            }
        }
        .background(Color.Theme.background)
        .navigationTitle(filterTransaction != nil ? String(localized: "Installments") : String(localized: "All Installments"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "Mark as Paid?"),
            isPresented: $showPaymentConfirmation,
            titleVisibility: .visible,
            presenting: installmentToConfirm
        ) { installment in
            Button(String(localized: "Mark as Paid")) {
                confirmPayment(installment)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                installmentToConfirm = nil
            }
        } message: { installment in
            Text(String(localized: "This will record a payment of \(CurrencyFormatter.string(installment.amount)) \(CurrencyFormatter.symbol) and reduce the salesman's balance."))
        }
    }
    
    private var viewModeToggle: some View {
        Picker("", selection: $viewMode) {
            ForEach(InstallmentsViewMode.allCases, id: \.self) { mode in
                Text(mode.localizedName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(Spacing.md)
    }
    
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.Theme.ink3)
            Text(String(localized: "No Installments"))
                .font(.headline)
                .foregroundStyle(Color.Theme.ink2)
            Text(String(localized: "Installment payments will appear here"))
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var installmentsList: some View {
        switch viewMode {
        case .byDueDate:
            byDueDateList
        case .byTransaction:
            byTransactionList
        }
    }
    
    private var byDueDateList: some View {
        List {
            ForEach(groupedByDueDate, id: \.0) { section in
                Section(header: Text(section.0)) {
                    ForEach(section.1) { installment in
                        InstallmentRowView(
                            installment: installment,
                            showTransactionInfo: true,
                            onTogglePaid: { togglePaid(installment) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var byTransactionList: some View {
        List {
            ForEach(groupedByTransaction, id: \.0.id) { (transaction, installments) in
                Section(header: transactionHeader(transaction)) {
                    ForEach(installments) { installment in
                        InstallmentRowView(
                            installment: installment,
                            showTransactionInfo: false,
                            onTogglePaid: { togglePaid(installment) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func transactionHeader(_ transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Items description (e.g., "3 × TV, 1 × Blender")
            if !transaction.items.isEmpty {
                let itemDescriptions = transaction.items.compactMap { item -> String? in
                    guard let productName = item.product?.name else { return nil }
                    return "\(item.quantity) × \(productName)"
                }
                Text(itemDescriptions.joined(separator: ", "))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                    .lineLimit(2)
            }
            
            // Date and amount
            HStack {
                Text(transaction.occurredAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(transaction.amount))
                        .fontWeight(.medium)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                }
                .foregroundStyle(Color.Theme.ink2)
            }
        }
    }
    
    private func togglePaid(_ installment: Installment) {
        if installment.isPaid {
            // Unpaid doesn't need confirmation - just undo
            do {
                try LedgerService.markInstallmentUnpaid(installment, in: modelContext)
            } catch {
                print("Failed to mark installment unpaid: \(error)")
            }
        } else {
            // Show confirmation before marking as paid
            installmentToConfirm = installment
            showPaymentConfirmation = true
        }
    }
    
    private func confirmPayment(_ installment: Installment) {
        do {
            try LedgerService.markInstallmentPaid(installment, in: modelContext)
        } catch {
            print("Failed to mark installment paid: \(error)")
        }
        installmentToConfirm = nil
    }
}

// MARK: - Installment Row View

struct InstallmentRowView: View {
    let installment: Installment
    let showTransactionInfo: Bool
    let onTogglePaid: () -> Void
    
    private var transactionSummary: String? {
        guard showTransactionInfo, let transaction = installment.transaction else { return nil }
        // Show first product name and total to identify the transaction
        if let firstItem = transaction.items.first, let productName = firstItem.product?.name {
            let totalQty = transaction.items.reduce(0) { $0 + $1.quantity }
            if totalQty > firstItem.quantity {
                return "\(productName) +\(transaction.items.count - 1)"
            }
            return productName
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Checkbox
            Button {
                onTogglePaid()
            } label: {
                Image(systemName: installment.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(installment.isPaid ? Color.Theme.success : statusColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if showTransactionInfo {
                    // Show transaction context when in "By Due Date" mode
                    HStack(spacing: Spacing.xs) {
                        if let summary = transactionSummary {
                            Text(summary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Theme.ink)
                                .lineLimit(1)
                        }
                        Text("·")
                            .foregroundStyle(Color.Theme.ink3)
                        Text(String(localized: "#\(installment.sequenceNumber) of \(installment.transaction?.installments.count ?? 0)"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                } else {
                    Text(String(localized: "Payment #\(installment.sequenceNumber)"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.string(installment.amount))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                        .strikethrough(installment.isPaid, color: Color.Theme.ink3)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                if installment.isPaid {
                    Text(String(localized: "Paid"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.success)
                } else {
                    statusBadge
                }
                
                Text(installment.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
    
    private var statusColor: Color {
        switch installment.status {
        case .paid:
            return Color.Theme.success
        case .overdue:
            return Color.Theme.warning
        case .dueSoon:
            return Color.Theme.accent
        case .upcoming:
            return Color.Theme.ink3
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        let status = installment.status
        if status != .upcoming {
            Text(status.localizedName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        InstallmentsListView(salesman: Salesman(name: "Ahmed"))
    }
    .modelContainer(for: [Salesman.self, Transaction.self, Installment.self])
}

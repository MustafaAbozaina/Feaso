import SwiftUI
import SwiftData

struct SalesmanDetailView: View {
    @Bindable var salesman: Salesman
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingEditSheet = false
    @State private var selectedTransaction: Transaction?
    @State private var showingReversalAlert = false
    @State private var navigateToGiveProducts = false
    @State private var navigateToRecordPayment = false
    
    private var sortedTransactions: [Transaction] {
        salesman.transactions.sorted { $0.occurredAt > $1.occurredAt }
    }
    
    private var hasActivity: Bool {
        !salesman.transactions.isEmpty
    }
    
    var body: some View {
        List {
            if hasActivity {
                balanceSection
            }
            
            actionButtonsSection
            
            if hasActivity {
                activitySection
            } else {
                emptyActivitySection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(salesman.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) {
                    showingEditSheet = true
                }
            }
        }
        .confirmationDialog(
            String(localized: "Transaction Options"),
            isPresented: Binding(
                get: { selectedTransaction != nil && !showingReversalAlert },
                set: { if !$0 { selectedTransaction = nil } }
            ),
            presenting: selectedTransaction
        ) { transaction in
            if !transaction.isReversed && !transaction.isReversal {
                Button(String(localized: "Reverse this transaction"), role: .destructive) {
                    showingReversalAlert = true
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                selectedTransaction = nil
            }
        }
        .alert(
            String(localized: "Reverse Transaction?"),
            isPresented: $showingReversalAlert,
            presenting: selectedTransaction
        ) { transaction in
            Button(String(localized: "Reverse"), role: .destructive) {
                reverseTransaction(transaction)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                selectedTransaction = nil
            }
        } message: { _ in
            Text(String(localized: "This creates a new entry that undoes it. The original is preserved for the record."))
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                SalesmanEditorView(salesman: salesman)
            }
        }
        .navigationDestination(isPresented: $navigateToGiveProducts) {
            GiveProductsView(salesman: salesman)
        }
        .navigationDestination(isPresented: $navigateToRecordPayment) {
            RecordPaymentView(salesman: salesman)
        }
    }
    
    // MARK: - Sections
    
    private var balanceSection: some View {
        Section {
            BalanceHeroCard(
                balance: salesman.balance,
                isSettled: salesman.isSettled
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var actionButtonsSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                Button {
                    navigateToGiveProducts = true
                } label: {
                    Label {
                        Text("Gave products")
                    } icon: {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Theme.accent)
                
                Button {
                    navigateToRecordPayment = true
                } label: {
                    Label(String(localized: "Record payment"), systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.Theme.success)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var activitySection: some View {
        Section {
            ForEach(sortedTransactions) { transaction in
                ActivityRow(transaction: transaction)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTransaction = transaction
                    }
            }
        } header: {
            Text(String(localized: "Activity"))
                .textCase(.uppercase)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var emptyActivitySection: some View {
        Section {
            VStack(spacing: Spacing.sm) {
                Text(String(localized: "No activity yet"))
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.ink2)
                Text(String(localized: "Record a distribution or payment to begin."))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
    }
    
    // MARK: - Actions
    
    private func reverseTransaction(_ transaction: Transaction) {
        do {
            try LedgerService.reverse(transaction, in: modelContext)
        } catch {
            // In production, show an alert
            print("Failed to reverse transaction: \(error)")
        }
        selectedTransaction = nil
    }
}

#Preview {
    NavigationStack {
        SalesmanDetailView(salesman: {
            let s = Salesman(name: "Ahmed", phone: "+201001234567")
            return s
        }())
    }
    .modelContainer(for: [Salesman.self, Product.self, Transaction.self, TransactionItem.self])
}

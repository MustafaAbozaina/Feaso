import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    @Bindable var customer: Customer
    
    @State private var showingEditSheet = false
    @State private var showingStatementSheet = false
    @State private var selectedTransaction: Transaction?
    @State private var navigateToGiveProducts = false
    @State private var navigateToRecordPayment = false
    @State private var navigateToReturnProducts = false
    @State private var navigateToInstallments = false
    
    private var sortedTransactions: [Transaction] {
        customer.transactions.sorted { $0.occurredAt > $1.occurredAt }
    }
    
    private var hasActivity: Bool {
        !customer.transactions.isEmpty
    }
    
    private var hasInstallments: Bool {
        customer.transactions.contains { $0.hasInstallments && $0.reversedBy == nil }
    }
    
    private var unpaidInstallmentsCount: Int {
        customer.transactions
            .filter { $0.reversedBy == nil }
            .flatMap { $0.installments }
            .filter { !$0.isPaid }
            .count
    }
    
    var body: some View {
        List {
            if hasActivity {
                balanceSection
            }
            
            if hasInstallments {
                installmentsSection
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
        .navigationTitle(customer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.sm) {
                    Button {
                        showingStatementSheet = true
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .disabled(!hasActivity)
                    
                    Button(String(localized: "Edit")) {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                CustomerEditorView(customer: customer)
            }
        }
        .sheet(isPresented: $showingStatementSheet) {
            StatementPreviewView(customer: customer)
        }
        .navigationDestination(isPresented: $navigateToGiveProducts) {
            GiveProductsView(customer: customer)
        }
        .navigationDestination(isPresented: $navigateToRecordPayment) {
            RecordPaymentView(customer: customer)
        }
        .navigationDestination(isPresented: $navigateToReturnProducts) {
            ReturnProductsView(customer: customer)
        }
        .navigationDestination(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .navigationDestination(isPresented: $navigateToInstallments) {
            InstallmentsListView(customer: customer)
        }
    }
    
    // MARK: - Sections
    
    private var balanceSection: some View {
        Section {
            BalanceHeroCard(
                balance: customer.balance,
                isSettled: customer.isSettled
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    
    private var installmentsSection: some View {
        Section {
            Button {
                navigateToInstallments = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(Color.Theme.accent)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Installments"))
                            .font(.body)
                            .foregroundStyle(Color.Theme.ink)
                        
                        if unpaidInstallmentsCount > 0 {
                            Text(String(localized: "\(unpaidInstallmentsCount) unpaid"))
                                .font(.caption)
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var actionButtonsSection: some View {
        Section {
            VStack(spacing: Spacing.sm) {
                // Primary actions row
                HStack(spacing: Spacing.md) {
                    Button {
                        navigateToGiveProducts = true
                    } label: {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.white)
                            Text(String(localized: "Sell products"))
                                .font(.subheadline)
                                .minimumScaleFactor(0.75)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .font(.subheadline)
                        .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Theme.accent)
                    
                    Button {
                        navigateToRecordPayment = true
                    } label: {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "checkmark.circle")
                            Text(String(localized: "Record payment"))
                                .font(.subheadline)
                                .minimumScaleFactor(0.75)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .font(.subheadline)
                        .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Theme.success)
                }
                
                // Secondary action: Return
                Button {
                    navigateToReturnProducts = true
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "arrow.uturn.backward.circle")
                        Text(String(localized: "Record return"))
                            .font(.subheadline)
                            .minimumScaleFactor(0.75)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .frame(height: 40)
                }
                .buttonStyle(.bordered)
                .tint(Color.Theme.ink2)
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
                Text(String(localized: "Record a sale or payment to begin."))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
    }
    
}

#Preview {
    NavigationStack {
        CustomerDetailView(customer: {
            let c = Customer(name: "Ahmed", phone: "+201001234567")
            return c
        }())
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

import SwiftUI
import SwiftData

struct SalesmanDetailView: View {
    @Bindable var salesman: Salesman
    
    @State private var showingEditSheet = false
    @State private var showingStatementSheet = false
    @State private var selectedTransaction: Transaction?
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
                SalesmanEditorView(salesman: salesman)
            }
        }
        .sheet(isPresented: $showingStatementSheet) {
            StatementPreviewView(salesman: salesman)
        }
        .navigationDestination(isPresented: $navigateToGiveProducts) {
            GiveProductsView(salesman: salesman)
        }
        .navigationDestination(isPresented: $navigateToRecordPayment) {
            RecordPaymentView(salesman: salesman)
        }
        .navigationDestination(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
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
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.white)
                        Text("Gave products")
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
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.white)
                        Text("Record payment")
                            .font(.subheadline)
                            .minimumScaleFactor(0.75)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .frame(height: 40)
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

import SwiftUI
import SwiftData

struct CustomersListView: View {
    @Query(filter: #Predicate<Customer> { $0.deletedAt == nil })
    private var customers: [Customer]
    
    @State private var showingAddSheet = false
    
    private var owing: [Customer] {
        customers
            .filter { $0.balance > 0 }
            .sorted { $0.balance > $1.balance }
    }
    
    private var overpaid: [Customer] {
        customers
            .filter { $0.balance < 0 }
            .sorted { $0.balance < $1.balance }
    }
    
    private var settled: [Customer] {
        customers
            .filter { $0.balance == 0 }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    private var totalOutstanding: Decimal {
        owing.reduce(Decimal(0)) { $0 + $1.balance }
    }
    
    private var owingCount: Int {
        owing.count
    }
    
    var body: some View {
        Group {
            if customers.isEmpty {
                emptyState
            } else {
                customersList
            }
        }
        .navigationTitle(String(localized: "Customers"))
        .background(Color.Theme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                CustomerEditorView()
            }
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            systemImage: "person.2",
            title: String(localized: "No Customers"),
            message: String(localized: "Add your first customer to start tracking sales."),
            actionTitle: String(localized: "Add Customer"),
            action: { showingAddSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var customersList: some View {
        List {
            Section {
                SummaryCard(
                    title: String(localized: "Total Outstanding"),
                    amount: totalOutstanding,
                    subtitle: String(localized: "\(owingCount) customers with balance")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            if !owing.isEmpty {
                Section {
                    ForEach(owing) { customer in
                        NavigationLink(value: customer) {
                            CustomerRow(customer: customer, isSettled: false)
                        }
                    }
                } header: {
                    Text(String(localized: "Owed to you"))
                        .textCase(.uppercase)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if !overpaid.isEmpty {
                Section {
                    ForEach(overpaid) { customer in
                        NavigationLink(value: customer) {
                            CustomerRow(customer: customer, isSettled: false)
                        }
                    }
                } header: {
                    Text(String(localized: "You owe them"))
                        .textCase(.uppercase)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if !settled.isEmpty {
                Section {
                    ForEach(settled) { customer in
                        NavigationLink(value: customer) {
                            CustomerRow(customer: customer, isSettled: true)
                        }
                    }
                } header: {
                    Text(String(localized: "Settled"))
                        .textCase(.uppercase)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await SyncService.shared.refresh()
        }
        .navigationDestination(for: Customer.self) { customer in
            CustomerDetailView(customer: customer)
        }
    }
}

#Preview {
    NavigationStack {
        CustomersListView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

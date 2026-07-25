import SwiftUI
import SwiftData

struct SalesmenListView: View {
    @Query(filter: #Predicate<Salesman> { $0.deletedAt == nil })
    private var salesmen: [Salesman]
    
    @State private var showingAddSheet = false
    
    private var owing: [Salesman] {
        salesmen
            .filter { $0.balance > 0 }
            .sorted { $0.balance > $1.balance }
    }
    
    private var overpaid: [Salesman] {
        salesmen
            .filter { $0.balance < 0 }
            .sorted { $0.balance < $1.balance }
    }
    
    private var settled: [Salesman] {
        salesmen
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
            if salesmen.isEmpty {
                emptyState
            } else {
                salesmenList
            }
        }
        .navigationTitle(String(localized: "Salesmen"))
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
                SalesmanEditorView()
            }
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            systemImage: "person.2",
            title: String(localized: "No Salesmen"),
            message: String(localized: "Add your first salesman to start tracking distributions."),
            actionTitle: String(localized: "Add Salesman"),
            action: { showingAddSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var salesmenList: some View {
        List {
            Section {
                SummaryCard(
                    title: String(localized: "Total Outstanding"),
                    amount: totalOutstanding,
                    subtitle: String(localized: "\(owingCount) salesmen with balance")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            if !owing.isEmpty {
                Section {
                    ForEach(owing) { salesman in
                        NavigationLink(value: salesman) {
                            SalesmanRow(salesman: salesman, isSettled: false)
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
                    ForEach(overpaid) { salesman in
                        NavigationLink(value: salesman) {
                            SalesmanRow(salesman: salesman, isSettled: false)
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
                    ForEach(settled) { salesman in
                        NavigationLink(value: salesman) {
                            SalesmanRow(salesman: salesman, isSettled: true)
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
        .navigationDestination(for: Salesman.self) { salesman in
            SalesmanDetailView(salesman: salesman)
        }
    }
}

#Preview {
    NavigationStack {
        SalesmenListView()
    }
    .modelContainer(for: [Salesman.self, Product.self, Transaction.self, TransactionItem.self])
}

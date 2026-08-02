import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<Transaction> { $0.reversedBy == nil })
    private var allTransactions: [Transaction]
    
    @Query(filter: #Predicate<Product> { $0.deletedAt == nil })
    private var products: [Product]
    
    @Query(filter: #Predicate<Customer> { $0.deletedAt == nil })
    private var customers: [Customer]
    
    @Query(filter: #Predicate<Installment> { $0.isPaid == false })
    private var unpaidInstallments: [Installment]
    
    @State private var showingQuickSale = false
    @State private var selectedTab: Tab = .home
    
    // MARK: - Computed Properties
    
    private var todayTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allTransactions.filter { calendar.isDate($0.occurredAt, inSameDayAs: today) }
    }
    
    private var todayCashReceived: Decimal {
        // Cash from payments + Quick sales (distributions with immediate payment)
        let payments = todayTransactions
            .filter { $0.type == .payment }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
        return payments
    }
    
    private var todayCreditGiven: Decimal {
        // Distributions with installment payment type
        todayTransactions
            .filter { $0.type == .distribution && $0.paymentType == .installment }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var todaySalesCount: Int {
        todayTransactions.filter { $0.type == .distribution }.count
    }
    
    private var overdueInstallments: [Installment] {
        unpaidInstallments.filter { $0.isOverdue }
    }
    
    private var dueThisWeekInstallments: [Installment] {
        let calendar = Calendar.current
        let today = Date()
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        return unpaidInstallments.filter { !$0.isOverdue && $0.dueDate <= weekFromNow }
    }
    
    private var totalOutstanding: Decimal {
        customers.reduce(Decimal(0)) { sum, customer in
            sum + max(0, customer.balance)
        }
    }
    
    private var overdueAmount: Decimal {
        overdueInstallments.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var lowStockProducts: [Product] {
        products.filter { $0.stockStatus == .low || $0.stockStatus == .outOfStock }
    }
    
    private var thisMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        return allTransactions.filter { $0.occurredAt >= startOfMonth }
    }
    
    private var thisMonthSales: Decimal {
        thisMonthTransactions
            .filter { $0.type == .distribution }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    private var thisMonthCollected: Decimal {
        thisMonthTransactions
            .filter { $0.type == .payment }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Quick Sale Button
                quickSaleButton
                
                // Today Section
                todaySection
                
                // Collections Due Section
                collectionsDueSection
                
                // Outstanding Section
                outstandingSection
                
                // Inventory Section
                inventorySection
                
                // This Month Section
                thisMonthSection
            }
            .padding(Spacing.lg)
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Home"))
        .sheet(isPresented: $showingQuickSale) {
            NavigationStack {
                QuickSaleView()
            }
        }
        .refreshable {
            await SyncService.shared.refresh()
        }
    }
    
    // MARK: - Quick Sale Button
    
    private var quickSaleButton: some View {
        Button {
            showingQuickSale = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                Text(String(localized: "Quick Sale"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(Color.Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
    }
    
    // MARK: - Today Section
    
    private var todaySection: some View {
        DashboardSection(
            title: String(localized: "Today"),
            destination: TransactionsView()
        ) {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "banknote")
                            .foregroundStyle(Color.Theme.success)
                        Text(String(localized: "Cash"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text(CurrencyFormatter.string(todayCashReceived))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "doc.plaintext")
                            .foregroundStyle(Color.Theme.accent)
                        Text(String(localized: "Credit"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text(CurrencyFormatter.string(todayCreditGiven))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "cart")
                            .foregroundStyle(Color.Theme.ink2)
                        Text(String(localized: "Sales"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                    Text("\(todaySalesCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                }
            }
        }
    }
    
    // MARK: - Collections Due Section
    
    private var collectionsDueSection: some View {
        DashboardSectionWithTabNavigation(
            title: String(localized: "Collections Due"),
            targetTab: .collections,
            selectedTab: $selectedTab
        ) {
            HStack(spacing: Spacing.lg) {
                if overdueInstallments.isEmpty && dueThisWeekInstallments.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.Theme.success)
                        Text(String(localized: "No payments due"))
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                } else {
                    if !overdueInstallments.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Theme.danger)
                            Text(String(localized: "\(overdueInstallments.count) overdue"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Theme.danger)
                        }
                    }
                    
                    if !dueThisWeekInstallments.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.Theme.warning)
                            Text(String(localized: "\(dueThisWeekInstallments.count) due this week"))
                                .font(.subheadline)
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Outstanding Section
    
    private var outstandingSection: some View {
        DashboardSectionWithTabNavigation(
            title: String(localized: "Outstanding"),
            targetTab: .customers,
            selectedTab: $selectedTab
        ) {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "Total Owed"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyFormatter.string(totalOutstanding))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
                
                Spacer()
                
                if overdueAmount > 0 {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(String(localized: "Overdue"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(CurrencyFormatter.string(overdueAmount))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.Theme.danger)
                            Text(CurrencyFormatter.symbol)
                                .font(.caption)
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Inventory Section
    
    private var inventorySection: some View {
        DashboardSectionWithTabNavigation(
            title: String(localized: "Inventory"),
            targetTab: .products,
            selectedTab: $selectedTab
        ) {
            HStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(Color.Theme.accent)
                    Text(String(localized: "\(products.count) products"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink)
                }
                
                Spacer()
                
                if !lowStockProducts.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.Theme.warning)
                        Text(String(localized: "\(lowStockProducts.count) low stock"))
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.warning)
                    }
                }
            }
        }
    }
    
    // MARK: - This Month Section
    
    private var thisMonthSection: some View {
        DashboardSection(
            title: String(localized: "This Month"),
            destination: MonthlyReportView()
        ) {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "Sales"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyFormatter.string(thisMonthSales))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "Collected"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyFormatter.string(thisMonthCollected))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.success)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
            }
        }
    }
}

// MARK: - Tab Enum for Navigation

enum Tab: Hashable {
    case home
    case customers
    case collections
    case products
    case settings
}

// MARK: - Dashboard Section Component

private struct DashboardSection<Content: View, Destination: View>: View {
    let title: String
    let destination: Destination
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NavigationLink(destination: destination) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Spacer()
                    
                    HStack(spacing: Spacing.xs) {
                        Text(String(localized: "See All"))
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.accent)
                        Image(systemName: "chevron.forward")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.accent)
                    }
                }
            }
            
            content()
                .padding(Spacing.md)
                .background(Color.Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}

// MARK: - Dashboard Section with Tab Navigation

private struct DashboardSectionWithTabNavigation<Content: View>: View {
    let title: String
    let targetTab: Tab
    @Binding var selectedTab: Tab
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                // Post notification to switch tab
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: nil,
                    userInfo: ["tab": targetTab]
                )
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Spacer()
                    
                    HStack(spacing: Spacing.xs) {
                        Text(String(localized: "See All"))
                            .font(.subheadline)
                            .foregroundStyle(Color.Theme.accent)
                        Image(systemName: "chevron.forward")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.accent)
                    }
                }
            }
            
            content()
                .padding(Spacing.md)
                .background(Color.Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let switchTab = Notification.Name("switchTab")
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self, Installment.self])
}

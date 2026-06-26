import SwiftUI
import SwiftData
import UIKit

struct RecordPaymentView: View {
    let salesman: Salesman
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var amountText = ""
    @State private var note = ""
    @State private var showingOverpaymentAlert = false
    @FocusState private var isAmountFocused: Bool
    
    private var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }
    
    private var projectedBalance: Decimal {
        salesman.balance - amount
    }
    
    private var isOverpayment: Bool {
        amount > salesman.balance
    }
    
    private var overpaymentAmount: Decimal {
        amount - salesman.balance
    }
    
    private var canConfirm: Bool {
        amount > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    amountCard
                    previewCard
                    noteField
                }
                .padding(Spacing.lg)
            }
            
            confirmButton
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Payment from \(salesman.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isAmountFocused = true
        }
        .alert(
            String(localized: "Overpayment"),
            isPresented: $showingOverpaymentAlert
        ) {
            Button(String(localized: "Record Overpayment"), role: .destructive) {
                confirmPayment()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This is more than \(salesman.name) currently owes. Record an overpayment of \(CurrencyFormatter.string(overpaymentAmount)) EGP?"))
        }
    }
    
    // MARK: - Amount Card
    
    private var amountCard: some View {
        VStack(spacing: Spacing.md) {
            Text(String(localized: "AMOUNT RECEIVED"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            TextField("0", text: $amountText)
                .font(.amountInput)
                .foregroundStyle(Color.Theme.success)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .focused($isAmountFocused)
            
            Text(String(localized: "\(salesman.name) currently owes \(CurrencyFormatter.string(salesman.balance)) EGP"))
                .font(.caption)
                .foregroundStyle(Color.Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
    
    // MARK: - Preview Card
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "AFTER THIS PAYMENT"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(String(localized: "\(salesman.name) will owe"))
                    .font(.body)
                    .foregroundStyle(Color.Theme.ink2)
                
                Spacer()
                
                Text(CurrencyFormatter.string(projectedBalance))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOverpayment ? Color.Theme.warning : Color.Theme.ink)
                
                Text(String(localized: "EGP"))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            if isOverpayment {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(String(localized: "Includes overpayment of \(CurrencyFormatter.string(overpaymentAmount)) EGP"))
                        .font(.caption)
                }
                .foregroundStyle(Color.Theme.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(isOverpayment ? Color.Theme.warningBg : Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
    
    // MARK: - Note Field
    
    private var noteField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "NOTE (OPTIONAL)"))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(Color.Theme.ink2)
            
            TextField(
                String(localized: "Cash, in person"),
                text: $note
            )
            .font(.body)
            .padding(Spacing.md)
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
    
    // MARK: - Confirm Button
    
    private var confirmButton: some View {
        Button {
            if isOverpayment {
                triggerWarningHaptic()
                showingOverpaymentAlert = true
            } else {
                confirmPayment()
            }
        } label: {
            Text(String(localized: "Confirm Payment"))
                .font(.body)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.Theme.success)
        .disabled(!canConfirm)
        .padding(Spacing.lg)
        .background(Color.Theme.surface2)
    }
    
    // MARK: - Actions
    
    private func confirmPayment() {
        do {
            try LedgerService.recordPayment(
                from: salesman,
                amount: amount,
                note: note.isEmpty ? nil : note,
                in: modelContext
            )
            triggerSuccessHaptic()
            dismiss()
        } catch {
            print("Failed to record payment: \(error)")
        }
    }
    
    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func triggerWarningHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

#Preview {
    NavigationStack {
        RecordPaymentView(salesman: {
            let s = Salesman(name: "Ahmed")
            return s
        }())
    }
    .modelContainer(for: [Salesman.self, Product.self, Transaction.self, TransactionItem.self])
}

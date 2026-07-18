import SwiftUI
import SwiftData

struct InstallmentEditorView: View {
    let transaction: Transaction
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var editableInstallments: [EditableInstallment] = []
    @State private var showingAddInstallment = false
    @State private var showingDeleteConfirmation = false
    @State private var installmentToDelete: EditableInstallment?
    
    private var totalAmount: Decimal {
        editableInstallments.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var hasChanges: Bool {
        let originalCount = transaction.installments.count
        let currentCount = editableInstallments.count
        
        if originalCount != currentCount { return true }
        
        for (index, editable) in editableInstallments.enumerated() {
            let original = transaction.sortedInstallments[index]
            if editable.amount != original.amount || 
               !Calendar.current.isDate(editable.dueDate, inSameDayAs: original.dueDate) {
                return true
            }
        }
        return false
    }
    
    private var isValid: Bool {
        !editableInstallments.isEmpty && totalAmount == transaction.amount
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(String(localized: "Transaction Total"))
                        .foregroundStyle(Color.Theme.ink)
                    Spacer()
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(transaction.amount))
                            .fontWeight(.semibold)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                HStack {
                    Text(String(localized: "Installments Total"))
                        .foregroundStyle(Color.Theme.ink)
                    Spacer()
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(totalAmount))
                            .fontWeight(.semibold)
                            .foregroundStyle(totalAmount == transaction.amount ? Color.Theme.ink : Color.Theme.warning)
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
            } footer: {
                if totalAmount != transaction.amount {
                    Text(String(localized: "Installments must equal transaction total"))
                        .foregroundStyle(Color.Theme.warning)
                }
            }
            
            Section(header: Text(String(localized: "Payments"))) {
                ForEach($editableInstallments) { $installment in
                    InstallmentEditRow(installment: $installment)
                }
                .onDelete(perform: deleteInstallments)
                
                Button {
                    addInstallment()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(String(localized: "Add Payment"))
                    }
                    .foregroundStyle(Color.Theme.accent)
                }
            }
            
            Section {
                Button {
                    redistributeEvenly()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(String(localized: "Redistribute Evenly"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Edit Installments"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    saveChanges()
                }
                .disabled(!isValid || !hasChanges)
            }
        }
        .onAppear {
            loadInstallments()
        }
        .alert(String(localized: "Delete Payment?"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let installment = installmentToDelete {
                    withAnimation {
                        editableInstallments.removeAll { $0.id == installment.id }
                        renumberInstallments()
                    }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This payment will be removed from the schedule."))
        }
    }
    
    private func loadInstallments() {
        editableInstallments = transaction.sortedInstallments.map { installment in
            EditableInstallment(
                id: installment.id,
                sequenceNumber: installment.sequenceNumber,
                amount: installment.amount,
                dueDate: installment.dueDate,
                isPaid: installment.isPaid
            )
        }
    }
    
    private func addInstallment() {
        let lastDate = editableInstallments.last?.dueDate ?? Date()
        let nextDate = Calendar.current.date(byAdding: .day, value: 14, to: lastDate) ?? lastDate
        let newInstallment = EditableInstallment(
            id: UUID(),
            sequenceNumber: editableInstallments.count + 1,
            amount: Decimal.zero,
            dueDate: nextDate,
            isPaid: false
        )
        withAnimation {
            editableInstallments.append(newInstallment)
        }
    }
    
    private func deleteInstallments(at offsets: IndexSet) {
        editableInstallments.remove(atOffsets: offsets)
        renumberInstallments()
    }
    
    private func renumberInstallments() {
        for (index, _) in editableInstallments.enumerated() {
            editableInstallments[index].sequenceNumber = index + 1
        }
    }
    
    private func redistributeEvenly() {
        guard !editableInstallments.isEmpty else { return }
        
        let count = editableInstallments.count
        let baseAmount = transaction.amount / Decimal(count)
        let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
        let remainder = transaction.amount - (roundedBase * Decimal(count))
        
        for (index, _) in editableInstallments.enumerated() {
            editableInstallments[index].amount = index == count - 1 ? roundedBase + remainder : roundedBase
        }
    }
    
    private func saveChanges() {
        let newInstallments = editableInstallments.map { editable in
            (sequenceNumber: editable.sequenceNumber, amount: editable.amount, dueDate: editable.dueDate)
        }
        
        do {
            try LedgerService.updateInstallments(
                for: transaction,
                newInstallments: newInstallments,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to save installments: \(error)")
        }
    }
}

// MARK: - Editable Installment

struct EditableInstallment: Identifiable {
    let id: UUID
    var sequenceNumber: Int
    var amount: Decimal
    var dueDate: Date
    var isPaid: Bool
}

// MARK: - Installment Edit Row

private struct InstallmentEditRow: View {
    @Binding var installment: EditableInstallment
    @State private var amountText: String = ""
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text(String(localized: "Payment #\(installment.sequenceNumber)"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                
                Spacer()
                
                if installment.isPaid {
                    Text(String(localized: "Paid"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Theme.success.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            HStack {
                Text(String(localized: "Amount"))
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.ink2)
                Spacer()
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                    .disabled(installment.isPaid)
                    .onChange(of: amountText) { _, newValue in
                        if let decimal = Decimal(string: newValue) {
                            installment.amount = decimal
                        }
                    }
                Text(CurrencyFormatter.symbol)
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            HStack {
                Text(String(localized: "Due Date"))
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.ink2)
                Spacer()
                DatePicker("", selection: $installment.dueDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(installment.isPaid)
            }
        }
        .padding(.vertical, Spacing.xs)
        .onAppear {
            amountText = "\(installment.amount)"
        }
    }
}

// MARK: - Decimal Extension

private extension Decimal {
    func rounded(scale: Int, roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, roundingMode)
        return result
    }
}

#Preview {
    NavigationStack {
        InstallmentEditorView(
            transaction: Transaction(type: .distribution, amount: 1500)
        )
    }
    .modelContainer(for: [Transaction.self, Installment.self])
}

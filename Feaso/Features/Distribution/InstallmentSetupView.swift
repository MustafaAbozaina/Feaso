import SwiftUI

struct InstallmentSetupView: View {
    let totalAmount: Decimal
    @Binding var numberOfInstallments: Int
    @Binding var firstDueDate: Date
    @Binding var interval: InstallmentInterval
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var customAmounts: [String] = []
    @State private var customDates: [Date] = []
    @State private var isCustomizingAmounts = false
    @State private var isCustomizingDates = false
    
    private var calculatedAmounts: [Decimal] {
        let baseAmount = totalAmount / Decimal(numberOfInstallments)
        let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
        let remainder = totalAmount - (roundedBase * Decimal(numberOfInstallments))
        
        return (0..<numberOfInstallments).map { index in
            index == numberOfInstallments - 1 ? roundedBase + remainder : roundedBase
        }
    }
    
    private var customDecimalAmounts: [Decimal] {
        customAmounts.compactMap { Decimal(string: $0) }
    }
    
    private var customAmountsTotal: Decimal {
        customDecimalAmounts.reduce(Decimal.zero) { $0 + $1 }
    }
    
    private var hasCustomAmountError: Bool {
        guard isCustomizingAmounts else { return false }
        return customDecimalAmounts.count != numberOfInstallments || customAmountsTotal != totalAmount
    }
    
    private var dueDates: [Date] {
        if isCustomizingDates && customDates.count == numberOfInstallments {
            return customDates
        }
        let calendar = Calendar.current
        return (0..<numberOfInstallments).map { index in
            calendar.date(byAdding: .day, value: interval.rawValue * index, to: firstDueDate) ?? firstDueDate
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(String(localized: "Total Amount"))
                            .foregroundStyle(Color.Theme.ink)
                        Spacer()
                        HStack(spacing: Spacing.xs) {
                            Text(CurrencyFormatter.string(totalAmount))
                                .fontWeight(.semibold)
                            Text(CurrencyFormatter.symbol)
                                .font(.caption)
                                .foregroundStyle(Color.Theme.ink3)
                        }
                    }
                }
                
                Section {
                    Stepper(value: $numberOfInstallments, in: 2...12) {
                        HStack {
                            Text(String(localized: "Payments"))
                            Spacer()
                            Text("\(numberOfInstallments)")
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                    .onChange(of: numberOfInstallments) { _, newValue in
                        updateCustomAmounts(for: newValue)
                    }
                    
                    DatePicker(
                        String(localized: "First Payment"),
                        selection: $firstDueDate,
                        displayedComponents: .date
                    )
                    
                    Picker(String(localized: "Interval"), selection: $interval) {
                        ForEach(InstallmentInterval.allCases) { interval in
                            Text(interval.localizedName).tag(interval)
                        }
                    }
                }
                
                Section {
                    Toggle(String(localized: "Custom Amounts"), isOn: $isCustomizingAmounts)
                        .onChange(of: isCustomizingAmounts) { _, newValue in
                            if newValue {
                                initializeCustomAmounts()
                            }
                        }
                    
                    Toggle(String(localized: "Custom Dates"), isOn: $isCustomizingDates)
                        .onChange(of: isCustomizingDates) { _, newValue in
                            if newValue {
                                initializeCustomDates()
                            }
                        }
                } footer: {
                    if isCustomizingAmounts && hasCustomAmountError {
                        Text(String(localized: "Amounts must equal \(CurrencyFormatter.string(totalAmount)) \(CurrencyFormatter.symbol)"))
                            .foregroundStyle(Color.Theme.warning)
                    }
                }
                
                Section(header: Text(String(localized: "Schedule"))) {
                    ForEach(0..<numberOfInstallments, id: \.self) { index in
                        VStack(spacing: Spacing.sm) {
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.Theme.ink2)
                                    .frame(width: 30, alignment: .leading)
                                
                                if isCustomizingAmounts {
                                    TextField("", text: amountBinding(for: index))
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                } else {
                                    HStack(spacing: Spacing.xs) {
                                        Text(CurrencyFormatter.string(calculatedAmounts[index]))
                                            .fontWeight(.medium)
                                        Text(CurrencyFormatter.symbol)
                                            .font(.caption)
                                            .foregroundStyle(Color.Theme.ink3)
                                    }
                                }
                                
                                Spacer()
                                
                                if isCustomizingDates {
                                    DatePicker("", selection: dateBinding(for: index), displayedComponents: .date)
                                        .labelsHidden()
                                } else {
                                    Text(dueDates[index], style: .date)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.Theme.ink2)
                                }
                            }
                        }
                    }
                }
                
                if isCustomizingAmounts {
                    Section {
                        HStack {
                            Text(String(localized: "Total"))
                                .fontWeight(.medium)
                            Spacer()
                            HStack(spacing: Spacing.xs) {
                                Text(CurrencyFormatter.string(customAmountsTotal))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(customAmountsTotal == totalAmount ? Color.Theme.ink : Color.Theme.warning)
                                Text(CurrencyFormatter.symbol)
                                    .font(.caption)
                                    .foregroundStyle(Color.Theme.ink3)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Customize Installments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .disabled(isCustomizingAmounts && hasCustomAmountError)
                }
            }
        }
    }
    
    private func amountBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < customAmounts.count ? customAmounts[index] : "" },
            set: { newValue in
                if index < customAmounts.count {
                    customAmounts[index] = newValue
                }
            }
        )
    }
    
    private func dateBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: { index < customDates.count ? customDates[index] : dueDates[index] },
            set: { newValue in
                if index < customDates.count {
                    customDates[index] = newValue
                }
            }
        )
    }
    
    private func initializeCustomAmounts() {
        customAmounts = calculatedAmounts.map { "\($0)" }
    }
    
    private func initializeCustomDates() {
        customDates = dueDates
    }
    
    private func updateCustomAmounts(for count: Int) {
        if isCustomizingAmounts {
            let newCalculated = {
                let baseAmount = totalAmount / Decimal(count)
                let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
                let remainder = totalAmount - (roundedBase * Decimal(count))
                
                return (0..<count).map { index in
                    index == count - 1 ? roundedBase + remainder : roundedBase
                }
            }()
            customAmounts = newCalculated.map { "\($0)" }
        }
        
        // Also update custom dates if customizing
        if isCustomizingDates {
            initializeCustomDates()
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
    InstallmentSetupView(
        totalAmount: Decimal(1500),
        numberOfInstallments: .constant(3),
        firstDueDate: .constant(Date()),
        interval: .constant(.biweekly)
    )
}

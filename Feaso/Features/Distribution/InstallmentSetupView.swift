import SwiftUI

struct InstallmentSetupView: View {
    let totalAmount: Decimal
    let initialNumberOfInstallments: Int
    let initialFirstDueDate: Date
    let initialInterval: InstallmentInterval
    let initialCustomAmounts: [Decimal]?
    let initialCustomDates: [Date]?
    let onSave: (Int, Date, InstallmentInterval, [Decimal]?, [Date]?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Local state for editing
    @State private var numberOfInstallments: Int
    @State private var firstDueDate: Date
    @State private var interval: InstallmentInterval
    @State private var customAmountsStrings: [String] = []
    @State private var customDatesLocal: [Date] = []
    @State private var isCustomizingAmounts = false
    @State private var isCustomizingDates = false
    
    init(
        totalAmount: Decimal,
        numberOfInstallments: Int,
        firstDueDate: Date,
        interval: InstallmentInterval,
        existingCustomAmounts: [Decimal]? = nil,
        existingCustomDates: [Date]? = nil,
        onSave: @escaping (Int, Date, InstallmentInterval, [Decimal]?, [Date]?) -> Void
    ) {
        self.totalAmount = totalAmount
        self.initialNumberOfInstallments = numberOfInstallments
        self.initialFirstDueDate = firstDueDate
        self.initialInterval = interval
        self.initialCustomAmounts = existingCustomAmounts
        self.initialCustomDates = existingCustomDates
        self.onSave = onSave
        
        // Initialize local state
        _numberOfInstallments = State(initialValue: numberOfInstallments)
        _firstDueDate = State(initialValue: firstDueDate)
        _interval = State(initialValue: interval)
        
        // Initialize custom amounts if they exist
        if let amounts = existingCustomAmounts {
            _customAmountsStrings = State(initialValue: amounts.map { "\($0)" })
            _isCustomizingAmounts = State(initialValue: true)
        }
        
        // Initialize custom dates if they exist
        if let dates = existingCustomDates {
            _customDatesLocal = State(initialValue: dates)
            _isCustomizingDates = State(initialValue: true)
        }
    }
    
    private var calculatedAmounts: [Decimal] {
        let baseAmount = totalAmount / Decimal(numberOfInstallments)
        let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
        let remainder = totalAmount - (roundedBase * Decimal(numberOfInstallments))
        
        return (0..<numberOfInstallments).map { index in
            index == numberOfInstallments - 1 ? roundedBase + remainder : roundedBase
        }
    }
    
    private var customDecimalAmounts: [Decimal] {
        customAmountsStrings.compactMap { Decimal(string: $0) }
    }
    
    private var customAmountsTotal: Decimal {
        customDecimalAmounts.reduce(Decimal.zero) { $0 + $1 }
    }
    
    private var dueDates: [Date] {
        if isCustomizingDates && customDatesLocal.count == numberOfInstallments {
            return customDatesLocal
        }
        let calendar = Calendar.current
        return (0..<numberOfInstallments).map { index in
            calendar.date(byAdding: .day, value: interval.rawValue * index, to: firstDueDate) ?? firstDueDate
        }
    }
    
    private var hasCustomAmountError: Bool {
        guard isCustomizingAmounts else { return false }
        return customDecimalAmounts.count != numberOfInstallments || customAmountsTotal != totalAmount
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
                        saveAndDismiss()
                    }
                    .disabled(isCustomizingAmounts && hasCustomAmountError)
                }
            }
        }
    }
    
    private func amountBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < customAmountsStrings.count ? customAmountsStrings[index] : "" },
            set: { newValue in
                guard index < customAmountsStrings.count else { return }
                
                // Update the current field
                customAmountsStrings[index] = newValue
                
                // Redistribute remaining amount to subsequent fields
                redistributeAmounts(afterIndex: index)
            }
        )
    }
    
    /// Redistributes the remaining amount equally across all fields after the given index
    private func redistributeAmounts(afterIndex editedIndex: Int) {
        let fieldsAfter = numberOfInstallments - editedIndex - 1
        guard fieldsAfter > 0 else { return }
        
        // Calculate sum of amounts from index 0 to editedIndex
        let sumBeforeAndIncluding = (0...editedIndex).reduce(Decimal.zero) { sum, i in
            let value = i < customAmountsStrings.count ? (Decimal(string: customAmountsStrings[i]) ?? Decimal.zero) : Decimal.zero
            return sum + value
        }
        
        // Calculate remaining amount to distribute
        let remaining = totalAmount - sumBeforeAndIncluding
        
        // Don't redistribute if remaining is negative (user entered more than total)
        guard remaining >= Decimal.zero else { return }
        
        // Distribute equally across remaining fields
        let baseAmount = remaining / Decimal(fieldsAfter)
        let roundedBase = baseAmount.rounded(scale: 2, roundingMode: .down)
        let totalRounded = roundedBase * Decimal(fieldsAfter)
        let lastFieldExtra = remaining - totalRounded
        
        // Update remaining fields
        for i in (editedIndex + 1)..<numberOfInstallments {
            if i < customAmountsStrings.count {
                if i == numberOfInstallments - 1 {
                    // Last field gets any rounding remainder
                    customAmountsStrings[i] = "\(roundedBase + lastFieldExtra)"
                } else {
                    customAmountsStrings[i] = "\(roundedBase)"
                }
            }
        }
    }
    
    private func dateBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: { 
                if index < customDatesLocal.count {
                    return customDatesLocal[index]
                }
                // Fallback to calculated date
                let calendar = Calendar.current
                return calendar.date(byAdding: .day, value: interval.rawValue * index, to: firstDueDate) ?? firstDueDate
            },
            set: { newValue in
                // Ensure array is properly sized
                while customDatesLocal.count <= index {
                    let calendar = Calendar.current
                    let nextIndex = customDatesLocal.count
                    let defaultDate = calendar.date(byAdding: .day, value: interval.rawValue * nextIndex, to: firstDueDate) ?? firstDueDate
                    customDatesLocal.append(defaultDate)
                }
                customDatesLocal[index] = newValue
            }
        )
    }
    
    private func initializeCustomAmounts() {
        customAmountsStrings = calculatedAmounts.map { "\($0)" }
    }
    
    private func initializeCustomDates() {
        // Initialize with calculated dates based on interval
        let calendar = Calendar.current
        customDatesLocal = (0..<numberOfInstallments).map { index in
            calendar.date(byAdding: .day, value: interval.rawValue * index, to: firstDueDate) ?? firstDueDate
        }
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
            customAmountsStrings = newCalculated.map { "\($0)" }
        }
        
        // Also update custom dates if customizing
        if isCustomizingDates {
            initializeCustomDates()
        }
    }
    
    private func saveAndDismiss() {
        // Determine custom amounts
        let customAmounts: [Decimal]? = if isCustomizingAmounts && !hasCustomAmountError {
            customDecimalAmounts
        } else {
            nil
        }
        
        // Determine custom dates
        let customDates: [Date]? = if isCustomizingDates && customDatesLocal.count == numberOfInstallments {
            customDatesLocal
        } else {
            nil
        }
        
        // Call the closure with all values
        onSave(numberOfInstallments, firstDueDate, interval, customAmounts, customDates)
        dismiss()
    }
}

#Preview {
    InstallmentSetupView(
        totalAmount: Decimal(1500),
        numberOfInstallments: 3,
        firstDueDate: Date(),
        interval: .biweekly,
        existingCustomAmounts: nil,
        existingCustomDates: nil,
        onSave: { _, _, _, _, _ in }
    )
}

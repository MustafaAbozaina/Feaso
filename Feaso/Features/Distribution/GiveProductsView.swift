import SwiftUI
import SwiftData

struct GiveProductsView: View {
    let customer: Customer
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var lines: [LineDraft] = []
    @State private var paymentType: PaymentType = .cash
    @State private var showingPicker = false
    @State private var showingDiscardAlert = false
    @State private var showingStockWarning = false
    @State private var attachedImage: UIImage?
    @State private var showingAttachmentSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    // Installment setup state
    @State private var numberOfInstallments: Int = 3
    @State private var firstDueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var installmentInterval: InstallmentInterval = .biweekly
    @State private var customAmounts: [Decimal]? = nil
    @State private var customDates: [Date]? = nil
    @State private var showingInstallmentCustomization = false
    
    private var newTotal: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.lineTotal }
    }
    
    private var projectedBalance: Decimal {
        customer.balance + newTotal
    }
    
    private var hasStockWarnings: Bool {
        lines.contains { $0.exceedsStock }
    }
    
    private var stockWarningMessage: String {
        let warnings = lines.filter { $0.exceedsStock }
        return warnings.map { line in
            String(localized: "\(line.product.name): only \(line.formattedStock) in stock, cart has \(line.formattedQuantity)")
        }.joined(separator: "\n")
    }
    
    private var excludedProductIDs: Set<UUID> {
        Set(lines.map { $0.product.id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            cartList
            footerBar
        }
        .background(Color.Theme.background)
        .navigationTitle(String(localized: "Sell to \(customer.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    if lines.isEmpty {
                        dismiss()
                    } else {
                        showingDiscardAlert = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                ProductPickerView(
                    onSelect: { product in
                        let initialQuantity = product.unit.defaultStep
                        lines.append(LineDraft(product: product, quantity: initialQuantity, paymentType: paymentType))
                    },
                    excludedProductIDs: excludedProductIDs
                )
            }
        }
        .alert(
            String(localized: "Discard Distribution?"),
            isPresented: $showingDiscardAlert
        ) {
            Button(String(localized: "Discard"), role: .destructive) {
                dismiss()
            }
            Button(String(localized: "Keep Editing"), role: .cancel) {}
        } message: {
            Text(String(localized: "Items will not be recorded."))
        }
        .alert(
            String(localized: "Stock Warning"),
            isPresented: $showingStockWarning
        ) {
            Button(String(localized: "Proceed Anyway"), role: .destructive) {
                confirmDistribution()
            }
            Button(String(localized: "Go Back"), role: .cancel) {}
        } message: {
            Text(stockWarningMessage)
        }
        .sheet(isPresented: $showingAttachmentSheet) {
            AttachmentSourceSheet(
                isPresented: $showingAttachmentSheet,
                onSelectCamera: {
                    showingCamera = true
                },
                onSelectLibrary: {
                    showingPhotoLibrary = true
                }
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: $attachedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(image: $attachedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingInstallmentCustomization) {
            InstallmentSetupView(
                totalAmount: newTotal,
                numberOfInstallments: numberOfInstallments,
                firstDueDate: firstDueDate,
                interval: installmentInterval,
                existingCustomAmounts: customAmounts,
                existingCustomDates: customDates,
                onSave: { newCount, newFirstDate, newInterval, newCustomAmounts, newCustomDates in
                    numberOfInstallments = newCount
                    firstDueDate = newFirstDate
                    installmentInterval = newInterval
                    customAmounts = newCustomAmounts
                    customDates = newCustomDates
                }
            )
        }
    }
    
    // MARK: - Cart List
    
    private var cartList: some View {
        List {
            paymentTypeSection
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            if paymentType == .installment {
                installmentSetupSection
                    .listRowInsets(EdgeInsets(
                        top: Spacing.sm,
                        leading: Spacing.lg,
                        bottom: Spacing.sm,
                        trailing: Spacing.lg
                    ))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            
            ForEach(lines) { line in
                CartItemCard(
                    line: line,
                    onQuantityChange: { newQuantity in
                        updateQuantity(for: line.id, to: newQuantity)
                    },
                    onPriceChange: { newPrice in
                        updatePrice(for: line.id, to: newPrice)
                    }
                )
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeLineWithID(line.id)
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                    }
                }
            }
            
            addProductButton
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            attachmentSection
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var paymentTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(String(localized: "Payment Type"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Theme.ink2)
            
            Picker("", selection: $paymentType) {
                Text(String(localized: "Cash")).tag(PaymentType.cash)
                Text(String(localized: "Installment")).tag(PaymentType.installment)
            }
            .pickerStyle(.segmented)
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .onChange(of: paymentType) { _, newValue in
            updateAllLinesPaymentType(to: newValue)
        }
    }
    
    private var installmentSetupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "Installment Schedule"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Theme.ink2)
            
            // Number of installments
            HStack {
                Text(String(localized: "Number of Payments"))
                    .font(.body)
                    .foregroundStyle(Color.Theme.ink)
                Spacer()
                Stepper("\(numberOfInstallments)", value: $numberOfInstallments, in: 2...12)
                    .labelsHidden()
                Text("\(numberOfInstallments)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
                    .frame(minWidth: 24)
            }
            
            Divider()
            
            // First due date
            HStack {
                Text(String(localized: "First Payment Due"))
                    .font(.body)
                    .foregroundStyle(Color.Theme.ink)
                Spacer()
                DatePicker("", selection: $firstDueDate, displayedComponents: .date)
                    .labelsHidden()
            }
            
            Divider()
            
            // Interval
            HStack {
                Text(String(localized: "Payment Interval"))
                    .font(.body)
                    .foregroundStyle(Color.Theme.ink)
                Spacer()
                Menu {
                    ForEach(InstallmentInterval.allCases) { interval in
                        Button(interval.localizedName) {
                            installmentInterval = interval
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(installmentInterval.localizedName)
                            .font(.body)
                            .foregroundStyle(Color.Theme.accent)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(Color.Theme.accent)
                    }
                }
            }
            
            Divider()
            
            // Preview
            installmentPreview
            
            // Customize button
            Button {
                showingInstallmentCustomization = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(String(localized: "Customize Amounts"))
                }
                .font(.subheadline)
                .foregroundStyle(Color.Theme.accent)
            }
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
    
    private var installmentPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(String(localized: "Preview"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink3)
                
                if customDates != nil || customAmounts != nil {
                    Text(String(localized: "(Customized)"))
                        .font(.caption2)
                        .foregroundStyle(Color.Theme.accent)
                }
            }
            
            let calendar = Calendar.current
            
            ForEach(0..<min(numberOfInstallments, 3), id: \.self) { index in
                // Use custom date if available, otherwise calculate
                let dueDate: Date = if let customDates, index < customDates.count {
                    customDates[index]
                } else {
                    calendar.date(byAdding: .day, value: installmentInterval.rawValue * index, to: firstDueDate) ?? firstDueDate
                }
                
                // Use custom amount if available, otherwise calculate evenly
                let amount: Decimal = if let customAmounts, index < customAmounts.count {
                    customAmounts[index]
                } else {
                    newTotal / Decimal(numberOfInstallments)
                }
                
                HStack {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                        .frame(width: 20, alignment: .leading)
                    Text(CurrencyFormatter.string(amount))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink)
                    Text(CurrencyFormatter.symbol)
                        .font(.caption2)
                        .foregroundStyle(Color.Theme.ink3)
                    Spacer()
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink2)
                }
            }
            
            if numberOfInstallments > 3 {
                Text(String(localized: "+\(numberOfInstallments - 3) more payments"))
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
        }
        .padding(Spacing.sm)
        .background(Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
    
    private var attachmentSection: some View {
        AttachmentButton(
            attachedImage: attachedImage,
            onTap: {
                showingAttachmentSheet = true
            },
            onRemove: {
                attachedImage = nil
            }
        )
    }
    
    private var addProductButton: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text(String(localized: "Add another product"))
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(Color.Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color.Theme.border2)
            )
        }
    }
    
    // MARK: - Footer Bar
    
    private var footerBar: some View {
        VStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(String(localized: "\(customer.name) will owe"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Theme.ink2)
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(projectedBalance))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Theme.ink)
                        
                        Text(CurrencyFormatter.symbol)
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                if !lines.isEmpty {
                    Text(String(localized: "Current \(CurrencyFormatter.string(customer.balance)) + new \(CurrencyFormatter.string(newTotal))"))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            Button {
                if hasStockWarnings {
                    showingStockWarning = true
                } else {
                    confirmDistribution()
                }
            } label: {
                Text(String(localized: "Confirm"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Theme.accent)
            .disabled(lines.isEmpty)
        }
        .padding(Spacing.lg)
        .background(Color.Theme.surface2)
    }
    
    // MARK: - Actions
    
    private func removeLineWithID(_ id: UUID) {
        lines.removeAll { $0.id == id }
    }
    
    private func updateQuantity(for id: UUID, to newQuantity: Decimal) {
        if let index = lines.firstIndex(where: { $0.id == id }) {
            lines[index].quantity = newQuantity
        }
    }
    
    private func updatePrice(for id: UUID, to newPrice: Decimal?) {
        if let index = lines.firstIndex(where: { $0.id == id }) {
            lines[index].unitPriceOverride = newPrice
        }
    }
    
    private func updateAllLinesPaymentType(to newPaymentType: PaymentType) {
        for index in lines.indices {
            lines[index].paymentType = newPaymentType
        }
    }
    
    private func confirmDistribution() {
        // Save attachment if present
        var attachmentFileName: String? = nil
        if let image = attachedImage {
            let transactionId = UUID()
            attachmentFileName = ImageAttachmentService.saveImage(image, for: transactionId)
        }
        
        // Create installment config if payment type is installment
        var installmentConfig: LedgerService.InstallmentConfig? = nil
        if paymentType == .installment {
            installmentConfig = LedgerService.InstallmentConfig(
                numberOfInstallments: numberOfInstallments,
                firstDueDate: firstDueDate,
                interval: installmentInterval,
                customAmounts: customAmounts,
                customDates: customDates
            )
        }
        
        let items = lines.map { (product: $0.product, quantity: $0.quantity, unitPriceOverride: $0.unitPriceOverride) }
        do {
            try LedgerService.recordDistribution(
                to: customer,
                items: items,
                paymentType: paymentType,
                installmentConfig: installmentConfig,
                attachmentFileName: attachmentFileName,
                in: modelContext
            )
            dismiss()
        } catch {
            print("Failed to record distribution: \(error)")
        }
    }
}

// MARK: - Cart Item Card

private struct CartItemCard: View {
    let line: LineDraft
    let onQuantityChange: (Decimal) -> Void
    let onPriceChange: (Decimal?) -> Void
    
    @State private var localQuantity: Decimal
    @State private var showingPriceEditor = false
    @State private var priceText: String = ""
    @FocusState private var isPriceFocused: Bool
    
    init(line: LineDraft, onQuantityChange: @escaping (Decimal) -> Void, onPriceChange: @escaping (Decimal?) -> Void) {
        self.line = line
        self.onQuantityChange = onQuantityChange
        self.onPriceChange = onPriceChange
        self._localQuantity = State(initialValue: line.quantity)
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack {
                QuantityStepper(
                    quantity: $localQuantity,
                    unit: line.productUnit,
                    onRemove: {},
                    warningThreshold: line.productCurrentStock
                )
                .onChange(of: localQuantity) { _, newValue in
                    onQuantityChange(newValue)
                }
                
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(CurrencyFormatter.string(line.lineTotal))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Theme.ink)
                    
                    Text(CurrencyFormatter.symbol)
                        .font(.caption)
                        .foregroundStyle(Color.Theme.ink3)
                }
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(line.productName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.ink)
            
                Spacer()
                
                // Editable price row
                Button {
                    priceText = "\(line.unitPrice)"
                    showingPriceEditor = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(CurrencyFormatter.string(line.unitPrice))
                            .fontWeight(line.hasCustomPrice ? .semibold : .regular)
                            .foregroundStyle(line.hasCustomPrice ? Color.Theme.accent : Color.Theme.ink2)
                        Text(CurrencyFormatter.symbol)
                            .foregroundStyle(Color.Theme.ink3)
                        
                        // Discount badge
                        if let discountText = line.discountDisplayText {
                            Text(discountText)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.Theme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.Theme.successBg)
                                .clipShape(Capsule())
                        }
                        
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(Color.Theme.accent)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                
                // Stock info
                HStack(spacing: Spacing.xs) {
                    if line.hasCustomPrice {
                        Text(String(localized: "was \(CurrencyFormatter.string(line.defaultUnitPrice))"))
                            .strikethrough()
                            .foregroundStyle(Color.Theme.ink3)
                        Text("·")
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    Text(line.formattedStock)
                    Text(String(localized: "in stock"))
                }
                .font(.caption)
                .foregroundStyle(line.exceedsStock ? Color.Theme.warning : Color.Theme.ink3)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .sheet(isPresented: $showingPriceEditor) {
            PriceEditorSheet(
                productName: line.productName,
                defaultPrice: line.defaultUnitPrice,
                currentPrice: line.unitPrice,
                onSave: { newPrice in
                    // If the new price equals the default, clear the override
                    if newPrice == line.defaultUnitPrice {
                        onPriceChange(nil)
                    } else {
                        onPriceChange(newPrice)
                    }
                },
                onReset: {
                    onPriceChange(nil)
                }
            )
            .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Price Editor Sheet

private struct PriceEditorSheet: View {
    let productName: String
    let defaultPrice: Decimal
    let currentPrice: Decimal
    let onSave: (Decimal) -> Void
    let onReset: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var priceText: String = ""
    @FocusState private var isFocused: Bool
    
    private var enteredPrice: Decimal {
        Decimal(string: priceText) ?? currentPrice
    }
    
    private var discountPercentage: Decimal {
        guard defaultPrice > 0 else { return 0 }
        return ((defaultPrice - enteredPrice) / defaultPrice) * 100
    }
    
    private var discountText: String? {
        let percentage = discountPercentage
        if percentage > 0 {
            return String(localized: "\(NSDecimalNumber(decimal: percentage.rounded(scale: 1)).intValue)% discount")
        } else if percentage < 0 {
            let markup = abs(percentage)
            return String(localized: "\(NSDecimalNumber(decimal: markup.rounded(scale: 1)).intValue)% markup")
        }
        return nil
    }
    
    private var hasChanges: Bool {
        enteredPrice != currentPrice
    }
    
    private var isCustomPrice: Bool {
        enteredPrice != defaultPrice
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Product name
                Text(productName)
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                
                // Price input
                VStack(spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        TextField("0", text: $priceText)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(isCustomPrice ? Color.Theme.accent : Color.Theme.ink)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                        
                        Text(CurrencyFormatter.symbol)
                            .font(.title3)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                    
                    // Discount/markup indicator
                    if let text = discountText {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: discountPercentage > 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            Text(text)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(discountPercentage > 0 ? Color.Theme.success : Color.Theme.warning)
                    }
                    
                    // Original price reference
                    if isCustomPrice {
                        Text(String(localized: "Original: \(CurrencyFormatter.string(defaultPrice)) \(CurrencyFormatter.symbol)"))
                            .font(.caption)
                            .foregroundStyle(Color.Theme.ink3)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: Spacing.sm) {
                    Button {
                        onSave(enteredPrice)
                        dismiss()
                    } label: {
                        Text(String(localized: "Apply Price"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Theme.accent)
                    .disabled(enteredPrice <= 0)
                    
                    if currentPrice != defaultPrice {
                        Button {
                            onReset()
                            dismiss()
                        } label: {
                            Text(String(localized: "Reset to Original"))
                                .font(.subheadline)
                                .foregroundStyle(Color.Theme.ink2)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .navigationTitle(String(localized: "Edit Price"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                priceText = "\(currentPrice)"
                isFocused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        GiveProductsView(customer: Customer(name: "Ahmed"))
    }
    .modelContainer(for: [Customer.self, Product.self, Transaction.self, TransactionItem.self])
}

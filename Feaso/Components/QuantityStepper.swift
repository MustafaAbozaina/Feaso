import SwiftUI
import UIKit

struct QuantityStepper: View {
    @Binding var quantity: Decimal
    let unit: ProductUnit
    let onRemove: () -> Void
    let warningThreshold: Decimal?
    
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var showWarning: Bool {
        guard let threshold = warningThreshold else { return false }
        return quantity > threshold
    }
    
    private var step: Decimal {
        unit.defaultStep
    }
    
    private var minimumQuantity: Decimal {
        unit.allowsDecimals ? step : 1
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                if quantity > minimumQuantity {
                    quantity -= step
                    if quantity < minimumQuantity {
                        quantity = minimumQuantity
                    }
                } else {
                    onRemove()
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.Theme.ink)
            
            if isEditing {
                TextField("", text: $editText)
                    .font(.body)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .keyboardType(unit.allowsDecimals ? .decimalPad : .numberPad)
                    .frame(minWidth: 56, minHeight: 32)
                    .padding(.horizontal, Spacing.xs)
                    .background(Color.Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(Color.Theme.accent, lineWidth: 2)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onChange(of: editText) { _, newText in
                        updateQuantityFromText(newText)
                    }
                    .onChange(of: quantity) { _, newQuantity in
                        // Sync editText when quantity changes externally (e.g., +/- buttons)
                        editText = unit.format(newQuantity)
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if !focused {
                            commitEdit()
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "Done")) {
                                commitEdit()
                            }
                            .fontWeight(.semibold)
                        }
                    }
            } else {
                // Tappable quantity display - show edit hint for decimal units
                VStack(spacing: 2) {
                    Text(unit.format(quantity))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(showWarning ? Color.Theme.warning : Color.Theme.ink)
                }
                .frame(minWidth: 48)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(
                            unit.allowsDecimals ? Color.Theme.accent.opacity(0.3) : Color.clear,
                            style: StrokeStyle(lineWidth: 1, dash: [3])
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    startEditing()
                }
            }
            
            Button {
                quantity += step
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.Theme.ink)
        }
        .background(Color.Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
    
    private func startEditing() {
        editText = unit.format(quantity)
        isEditing = true
        // Delay focus to ensure TextField is in view hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    private func updateQuantityFromText(_ text: String) {
        let cleanedText = text.replacingOccurrences(of: ",", with: ".")
        if let newValue = Decimal(string: cleanedText), newValue > 0 {
            if unit.allowsDecimals {
                quantity = newValue
            } else {
                quantity = Decimal(Int(truncating: newValue as NSDecimalNumber))
            }
        }
    }
    
    private func commitEdit() {
        // Parse the edited value before closing
        let cleanedText = editText.replacingOccurrences(of: ",", with: ".")
        if let newValue = Decimal(string: cleanedText), newValue > 0 {
            // Round to appropriate precision based on unit
            if unit.allowsDecimals {
                quantity = newValue
            } else {
                // For discrete units, round to nearest integer
                quantity = Decimal(Int(truncating: newValue as NSDecimalNumber))
            }
        }
        // If parsing fails, keep the original value
        
        isEditing = false
        isTextFieldFocused = false
    }
}

// MARK: - Convenience initializer for integer quantities (backward compatibility)

extension QuantityStepper {
    init(quantity: Binding<Int>, onRemove: @escaping () -> Void, warningThreshold: Int?) {
        self._quantity = Binding(
            get: { Decimal(quantity.wrappedValue) },
            set: { quantity.wrappedValue = Int(truncating: $0 as NSDecimalNumber) }
        )
        self.unit = .piece
        self.onRemove = onRemove
        self.warningThreshold = warningThreshold.map { Decimal($0) }
    }
}

#Preview {
    VStack(spacing: 20) {
        QuantityStepper(
            quantity: .constant(3),
            unit: .piece,
            onRemove: {},
            warningThreshold: nil
        )
        
        QuantityStepper(
            quantity: .constant(Decimal(string: "2.5")!),
            unit: .liter,
            onRemove: {},
            warningThreshold: Decimal(5)
        )
        
        QuantityStepper(
            quantity: .constant(Decimal(string: "1.25")!),
            unit: .kilogram,
            onRemove: {},
            warningThreshold: nil
        )
    }
    .padding()
}

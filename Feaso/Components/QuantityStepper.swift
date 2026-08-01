import SwiftUI
import UIKit

struct QuantityStepper: View {
    @Binding var quantity: Int
    let onRemove: () -> Void
    let warningThreshold: Int?
    
    private var showWarning: Bool {
        guard let threshold = warningThreshold else { return false }
        return quantity > threshold
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                if quantity > 1 {
                    quantity -= 1
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
            
            Text("\(quantity)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(showWarning ? Color.Theme.warning : Color.Theme.ink)
                .frame(minWidth: 32)
            
            Button {
                quantity += 1
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
}

#Preview {
    VStack(spacing: 20) {
        QuantityStepper(
            quantity: .constant(3),
            onRemove: {},
            warningThreshold: nil
        )
        
        QuantityStepper(
            quantity: .constant(15),
            onRemove: {},
            warningThreshold: 10
        )
    }
    .padding()
}

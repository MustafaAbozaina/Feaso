import SwiftUI

extension View {
    /// Filters text input to only allow integer digits (0-9)
    func numericInput(_ text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            let filtered = newValue.filter { $0 >= "0" && $0 <= "9" }
            if filtered != newValue {
                text.wrappedValue = filtered
            }
        }
    }
    
    /// Filters text input to only allow decimal numbers (0-9 and single decimal point)
    func decimalInput(_ text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            var filtered = newValue.filter { ($0 >= "0" && $0 <= "9") || $0 == "." }
            // Ensure only one decimal point
            if filtered.filter({ $0 == "." }).count > 1 {
                let parts = filtered.split(separator: ".", omittingEmptySubsequences: false)
                if parts.count > 1 {
                    filtered = parts[0] + "." + parts.dropFirst().joined()
                }
            }
            if filtered != newValue {
                text.wrappedValue = filtered
            }
        }
    }
}

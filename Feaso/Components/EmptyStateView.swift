import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Color.Theme.ink3)
            
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.Theme.ink)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.ink2)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Theme.accent)
            }
        }
        .padding(Spacing.xxl)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "person.2",
        title: "No Salesmen",
        message: "Add your first salesman to start tracking distributions.",
        actionTitle: "Add Salesman",
        action: {}
    )
}

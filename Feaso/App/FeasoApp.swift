import SwiftUI
import SwiftData

@main
struct FeasoApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let container = try ModelContainer(for: 
                Salesman.self,
                Product.self,
                Transaction.self,
                TransactionItem.self,
                Installment.self
            )
            self.modelContainer = container
            
            #if DEBUG
            Task { @MainActor in
                try? PreviewSeed.populateIfEmpty(container.mainContext)
            }
            #endif
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

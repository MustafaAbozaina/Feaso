import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FeasoApp: App {
    let modelContainer: ModelContainer
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        do {
            let container = try ModelContainer(for: 
                Customer.self,
                Product.self,
                Transaction.self,
                TransactionItem.self,
                Installment.self
            )
            self.modelContainer = container
            
            // Configure sync service with model context
            SyncService.shared.configure(with: container.mainContext)
            
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

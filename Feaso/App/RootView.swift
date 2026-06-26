import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SalesmenListView()
            }
            .tabItem {
                Label(String(localized: "Salesmen"), systemImage: "person.2.fill")
            }
            
            NavigationStack {
                ProductsListView()
            }
            .tabItem {
                Label(String(localized: "Products"), systemImage: "shippingbox.fill")
            }
        }
        .tint(Color.Theme.accent)
    }
}

#Preview {
    RootView()
}

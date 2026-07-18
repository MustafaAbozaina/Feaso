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
            
            CollectionsView()
            .tabItem {
                Label(String(localized: "Collections"), systemImage: "banknote.fill")
            }
            
            NavigationStack {
                ProductsListView()
            }
            .tabItem {
                Label(String(localized: "Products"), systemImage: "shippingbox.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(String(localized: "Settings"), systemImage: "gearshape.fill")
            }
        }
        .tint(Color.Theme.accent)
    }
}

#Preview {
    RootView()
}

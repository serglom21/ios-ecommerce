import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $appState.navigationPath) {
                HomeView()
                    .navigationDestination(for: String.self) { route in
                        routeDestination(route)
                    }
                    .navigationDestination(for: Product.self) { product in
                        ProductDetailView(product: product)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationStack {
                SearchView()
                    .navigationDestination(for: Product.self) { product in
                        ProductDetailView(product: product)
                    }
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            NavigationStack {
                CartView()
                    .navigationDestination(for: String.self) { route in
                        routeDestination(route)
                    }
            }
            .tabItem {
                Label("Cart", systemImage: "cart.fill")
            }
            .badge(appState.cart.itemCount > 0 ? appState.cart.itemCount : nil)
            .tag(2)
            
            NavigationStack {
                DebugSettingsView()
            }
            .tabItem {
                Label("Debug", systemImage: "gear")
            }
            .tag(3)
        }
        .onChange(of: selectedTab) { _, newValue in
            let routes = ["home", "search", "cart", "settings"]
            if newValue < routes.count {
                appState.navigateTo(routes[newValue])
            }
        }
    }
    
    @ViewBuilder
    private func routeDestination(_ route: String) -> some View {
        switch route {
        case "checkout":
            CheckoutView()
        case "payment":
            PaymentView()
        case "confirmation":
            if let order = appState.currentOrder {
                OrderConfirmationView(order: order)
            } else {
                Text("Order not found")
            }
        default:
            Text("Unknown route: \(route)")
        }
    }
}


import Foundation
import SwiftUI
import Sentry

/// Central app state - single source of truth
@MainActor
class AppState: ObservableObject {
    // Session
    let sessionId = UUID()
    @Published var isLoggedIn: Bool = false
    
    // Navigation
    @Published var currentRoute: String = "home"
    @Published var navigationPath = NavigationPath()
    
    // Cart
    @Published var cart: Cart = Cart(items: [], promoApplied: false, promoDiscount: 0)
    
    // Checkout state
    @Published var shippingAddress: Address = Address(street: "", city: "", state: "", zipCode: "", country: "US")
    @Published var selectedShippingOption: ShippingOption?
    @Published var taxQuote: TaxQuote?
    
    // Payment state
    @Published var selectedPaymentMethod: PaymentMethod = .card
    @Published var paymentIntent: PaymentIntent?
    @Published var paymentRetryCount: Int = 0
    
    // Order state
    @Published var currentOrder: Order?
    
    // Loading states
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Services (initialized lazily)
    lazy var catalogService = CatalogService(appState: self)
    lazy var cartService = CartService(appState: self)
    lazy var checkoutService = CheckoutService(appState: self)
    lazy var paymentService = PaymentService(appState: self)
    lazy var orderService = OrderService(appState: self)
    
    // MARK: - Navigation Tracking
    
    func navigateTo(_ route: String) {
        // SENTRY INSTRUMENTATION: Track navigation
        SentryInstrumentation.trackNavigation(from: currentRoute, to: route)
        currentRoute = route
    }
}


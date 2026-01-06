import Foundation

/// Mock backend with configurable latency and error injection
class MockBackend: ObservableObject {
    static let shared = MockBackend()
    
    @Published var latencyProfile: LatencyProfile = .normal
    @Published var failureInjection: [Endpoint: Bool] = [:]
    @Published var simulateOffline: Bool = false
    
    enum LatencyProfile: String, CaseIterable {
        case fast = "Fast (50-100ms)"
        case normal = "Normal (200-500ms)"
        case slow = "Slow (1-3s)"
        
        var range: ClosedRange<Double> {
            switch self {
            case .fast: return 0.05...0.1
            case .normal: return 0.2...0.5
            case .slow: return 1.0...3.0
            }
        }
    }
    
    enum Endpoint: String, CaseIterable {
        case search
        case productDetail
        case cart
        case shippingQuote
        case tax
        case payment
        case order
    }
    
    // MARK: - Mock Data
    
    private let mockProducts: [Product] = [
        Product(id: "1", name: "Wireless Headphones", description: "Premium noise-canceling headphones", price: 299.99, currency: "USD", imageURL: nil, category: "Electronics", inStock: true),
        Product(id: "2", name: "Smart Watch", description: "Fitness tracking smartwatch", price: 399.99, currency: "USD", imageURL: nil, category: "Electronics", inStock: true),
        Product(id: "3", name: "Laptop Stand", description: "Ergonomic aluminum stand", price: 49.99, currency: "USD", imageURL: nil, category: "Accessories", inStock: true),
        Product(id: "4", name: "USB-C Cable", description: "Fast charging cable 2m", price: 19.99, currency: "USD", imageURL: nil, category: "Accessories", inStock: true),
        Product(id: "5", name: "Mechanical Keyboard", description: "RGB backlit gaming keyboard", price: 149.99, currency: "USD", imageURL: nil, category: "Electronics", inStock: true),
        Product(id: "6", name: "Wireless Mouse", description: "Ergonomic wireless mouse", price: 79.99, currency: "USD", imageURL: nil, category: "Electronics", inStock: true),
        Product(id: "7", name: "Phone Case", description: "Protective silicone case", price: 24.99, currency: "USD", imageURL: nil, category: "Accessories", inStock: true),
        Product(id: "8", name: "Power Bank", description: "20,000mAh portable charger", price: 59.99, currency: "USD", imageURL: nil, category: "Electronics", inStock: true),
    ]
    
    // MARK: - Request Simulation
    
    private func simulateLatency() async throws {
        if simulateOffline {
            throw ServiceError.networkError
        }
        
        let delay = Double.random(in: latencyProfile.range)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    private func shouldFail(endpoint: Endpoint) -> Bool {
        failureInjection[endpoint] ?? false
    }
    
    // MARK: - API Methods
    
    func searchProducts(query: String) async throws -> [Product] {
        try await simulateLatency()
        
        if shouldFail(endpoint: .search) {
            throw ServiceError.networkError
        }
        
        // Simple search: filter by name containing query
        let lowercasedQuery = query.lowercased()
        let results = mockProducts.filter { product in
            product.name.lowercased().contains(lowercasedQuery) ||
            product.category.lowercased().contains(lowercasedQuery)
        }
        
        return results
    }
    
    func getProductDetail(id: String) async throws -> Product {
        try await simulateLatency()
        
        if shouldFail(endpoint: .productDetail) {
            throw ServiceError.notFoundError
        }
        
        guard let product = mockProducts.first(where: { $0.id == id }) else {
            throw ServiceError.notFoundError
        }
        
        return product
    }
    
    func getRecommendations(forProduct productId: String) async throws -> [Product] {
        try await simulateLatency()
        
        // Return random 3 products as recommendations
        return Array(mockProducts.shuffled().prefix(3))
    }
    
    func addToCart(productId: String, quantity: Int) async throws {
        try await simulateLatency()
        
        if shouldFail(endpoint: .cart) {
            throw ServiceError.providerError
        }
        
        // Success (in-memory cart handled by service layer)
    }
    
    func updateCartItem(itemId: String, quantity: Int) async throws {
        try await simulateLatency()
        
        if shouldFail(endpoint: .cart) {
            throw ServiceError.providerError
        }
    }
    
    func removeFromCart(itemId: String) async throws {
        try await simulateLatency()
        
        if shouldFail(endpoint: .cart) {
            throw ServiceError.providerError
        }
    }
    
    func validateAddress(_ address: Address) async throws -> Bool {
        try await simulateLatency()
        return address.isValid
    }
    
    func getShippingOptions(for address: Address) async throws -> [ShippingOption] {
        try await simulateLatency()
        
        if shouldFail(endpoint: .shippingQuote) {
            throw ServiceError.providerError
        }
        
        return [
            ShippingOption(id: "std", method: "standard", name: "Standard Shipping", price: 5.99, estimatedDays: 5),
            ShippingOption(id: "exp", method: "express", name: "Express Shipping", price: 15.99, estimatedDays: 2),
            ShippingOption(id: "pickup", method: "pickup", name: "Store Pickup", price: 0.0, estimatedDays: 1)
        ]
    }
    
    func calculateTax(amount: Double, address: Address) async throws -> TaxQuote {
        try await simulateLatency()
        
        if shouldFail(endpoint: .tax) {
            throw ServiceError.providerError
        }
        
        let rate = 0.08 // 8% tax rate
        return TaxQuote(amount: amount * rate, rate: rate, provider: "mock")
    }
    
    func createPaymentIntent(amount: Double, method: PaymentMethod) async throws -> PaymentIntent {
        try await simulateLatency()
        
        if shouldFail(endpoint: .payment) {
            // Simulate different payment failures
            let failures: [ServiceError] = [.providerError, .fraudError, .insufficientFundsError]
            throw failures.randomElement()!
        }
        
        // 30% chance of requiring 3DS
        let requires3DS = Double.random(in: 0...1) < 0.3
        
        return PaymentIntent(
            id: UUID().uuidString,
            amount: amount,
            currency: "USD",
            status: requires3DS ? "requires_action" : "succeeded",
            requiresAction: requires3DS
        )
    }
    
    func confirm3DS(paymentIntentId: String) async throws {
        try await simulateLatency()
        
        // Simulate 3DS challenge
        if Double.random(in: 0...1) < 0.1 { // 10% failure rate
            throw ServiceError.providerError
        }
    }
    
    func createOrder(
        items: [CartItem],
        shippingAddress: Address,
        shippingOption: ShippingOption,
        tax: TaxQuote,
        paymentIntentId: String
    ) async throws -> Order {
        try await simulateLatency()
        
        if shouldFail(endpoint: .order) {
            throw ServiceError.providerError
        }
        
        let subtotal = items.reduce(0.0) { $0 + $1.total }
        
        // Simulate inventory check (90% success)
        let inventoryAvailable = Double.random(in: 0...1) < 0.9
        
        let order = Order(
            id: UUID().uuidString,
            items: items,
            shippingAddress: shippingAddress,
            shippingMethod: shippingOption.method,
            subtotal: subtotal,
            shippingCost: shippingOption.price,
            tax: tax.amount,
            total: subtotal + shippingOption.price + tax.amount,
            paymentMethod: "card",
            status: inventoryAvailable ? "confirmed" : "backorder",
            createdAt: Date(),
            fulfillmentType: shippingOption.method == "pickup" ? "pickup" : "ship"
        )
        
        if !inventoryAvailable {
            // Still succeed but mark as backorder
            print("Order created but inventory on backorder")
        }
        
        return order
    }
    
    func sendNotification(orderId: String, channels: [String]) async throws {
        try await simulateLatency()
        // Simulate sending email/sms/push notifications
    }
}


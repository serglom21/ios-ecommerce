import Foundation
import Sentry

// MARK: - Catalog Service

@MainActor
class CatalogService {
    private let backend = MockBackend.shared
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Search for products
    func search(query: String) async throws -> [Product] {
        // SENTRY INSTRUMENTATION: Create transaction for search
        let transaction = SentryInstrumentation.startTransaction(
            name: "search.query",
            operation: "search.query"
        )
        SentryInstrumentation.setCommonContext(transaction)
        
        // Set search context
        transaction.setData(value: "mock", key: "search.backend")
        
        do {
            // Child span: API call
            let apiSpan = SentryInstrumentation.startChild(
                parent: transaction,
                name: "api.search",
                operation: "api.search"
            )
            
            let results = try await backend.searchProducts(query: query)
            
            // Record result count bucket (low-cardinality)
            let resultBucket = SentryInstrumentation.resultCountBucket(results.count)
            apiSpan.setData(value: resultBucket, key: "search.result_count_bucket")
            SentryInstrumentation.recordSuccess(apiSpan)
            
            // Child span: UI rendering
            let renderSpan = SentryInstrumentation.startChild(
                parent: transaction,
                name: "ui.render.results",
                operation: "ui.render.results"
            )
            renderSpan.setData(value: results.count, key: "result_count")
            renderSpan.finishSuccess()
            
            transaction.setData(value: resultBucket, key: "search.result_count_bucket")
            SentryInstrumentation.recordSuccess(transaction)
            
            return results
            
        } catch {
            SentryInstrumentation.recordFailure(transaction, error: error)
            throw error
        }
    }
    
    /// Get product details with recommendations
    func getProductDetail(id: String, includeRecommendations: Bool = true) async throws -> (Product, [Product]) {
        // SENTRY INSTRUMENTATION: Transaction for product detail load
        let transaction = SentryInstrumentation.startTransaction(
            name: "product.detail.load",
            operation: "product.detail.load"
        )
        SentryInstrumentation.setCommonContext(transaction)
        transaction.setData(value: id, key: "product.id")
        transaction.setData(value: includeRecommendations, key: "feature.reco_enabled")
        
        do {
            // Child span: Get product detail
            let detailSpan = SentryInstrumentation.startChild(
                parent: transaction,
                name: "api.product.detail",
                operation: "api.product.detail"
            )
            
            let product = try await backend.getProductDetail(id: id)
            SentryInstrumentation.recordSuccess(detailSpan)
            
            var recommendations: [Product] = []
            
            if includeRecommendations {
                // Child span: Get recommendations
                let recoSpan = SentryInstrumentation.startChild(
                    parent: transaction,
                    name: "api.recommendations",
                    operation: "api.recommendations"
                )
                
                do {
                    recommendations = try await backend.getRecommendations(forProduct: id)
                    SentryInstrumentation.recordSuccess(recoSpan)
                } catch {
                    // Recommendations are optional - don't fail the whole request
                    SentryInstrumentation.recordFailure(recoSpan, error: error)
                }
            }
            
            SentryInstrumentation.recordSuccess(transaction)
            return (product, recommendations)
            
        } catch {
            SentryInstrumentation.recordFailure(transaction, error: error)
            throw error
        }
    }
}

// MARK: - Cart Service

@MainActor
class CartService {
    private let backend = MockBackend.shared
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Add item to cart
    func addItem(product: Product, quantity: Int = 1) async throws {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Cart add item
        let span = SentryInstrumentation.startTransaction(
            name: "cart.add_item",
            operation: "cart.add_item"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: product.id, key: "product.id")
        span.setData(value: quantity, key: "quantity")
        
        do {
            // Child span: API call
            let apiSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.cart.add",
                operation: "api.cart.add"
            )
            
            try await backend.addToCart(productId: product.id, quantity: quantity)
            SentryInstrumentation.recordSuccess(apiSpan)
            
            // Child span: Pricing recalculation
            let pricingSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "pricing.recalc",
                operation: "pricing.recalc"
            )
            
            // Update local cart
            let cartItem = CartItem(id: UUID().uuidString, product: product, quantity: quantity)
            appState.cart.items.append(cartItem)
            
            // Set cart attributes (low-cardinality)
            pricingSpan.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
            pricingSpan.setData(value: appState.cart.valueBucket, key: "cart.value_bucket")
            pricingSpan.setData(value: appState.cart.promoApplied, key: "promo.applied")
            pricingSpan.setData(value: "USD", key: "currency")
            pricingSpan.finishSuccess()
            
            span.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
            span.setData(value: appState.cart.valueBucket, key: "cart.value_bucket")
            SentryInstrumentation.recordSuccess(span)
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Update item quantity
    func updateQuantity(itemId: String, quantity: Int) async throws {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Update cart quantity
        let span = SentryInstrumentation.startTransaction(
            name: "cart.update_quantity",
            operation: "cart.update_quantity"
        )
        SentryInstrumentation.setCommonContext(span)
        
        do {
            try await backend.updateCartItem(itemId: itemId, quantity: quantity)
            
            if let index = appState.cart.items.firstIndex(where: { $0.id == itemId }) {
                appState.cart.items[index] = CartItem(
                    id: itemId,
                    product: appState.cart.items[index].product,
                    quantity: quantity
                )
            }
            
            span.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
            SentryInstrumentation.recordSuccess(span)
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Remove item from cart
    func removeItem(itemId: String) async throws {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Remove cart item
        let span = SentryInstrumentation.startTransaction(
            name: "cart.remove_item",
            operation: "cart.remove_item"
        )
        SentryInstrumentation.setCommonContext(span)
        
        do {
            try await backend.removeFromCart(itemId: itemId)
            
            appState.cart.items.removeAll { $0.id == itemId }
            
            span.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
            SentryInstrumentation.recordSuccess(span)
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Toggle promo code
    func togglePromo() {
        guard let appState = appState else { return }
        
        appState.cart.promoApplied.toggle()
        appState.cart.promoDiscount = appState.cart.promoApplied ? 10.0 : 0.0
    }
}

// MARK: - Checkout Service

@MainActor
class CheckoutService {
    private let backend = MockBackend.shared
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Start checkout flow
    func startCheckout() {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Checkout start
        let span = SentryInstrumentation.startTransaction(
            name: "checkout.start",
            operation: "checkout.start"
        )
        SentryInstrumentation.setCommonContext(span)
        
        let checkoutType = appState.isLoggedIn ? "logged_in" : "guest"
        span.setData(value: checkoutType, key: "checkout.type")
        span.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
        span.setData(value: appState.cart.valueBucket, key: "cart.value_bucket")
        
        SentryInstrumentation.recordSuccess(span)
    }
    
    /// Submit and validate address
    func submitAddress(_ address: Address) async throws {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Address submission
        let span = SentryInstrumentation.startTransaction(
            name: "checkout.address.submit",
            operation: "checkout.address.submit"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: address.country, key: "address.country")
        
        do {
            // Child span: Address validation
            let validationSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.address.validate",
                operation: "api.address.validate"
            )
            
            let isValid = try await backend.validateAddress(address)
            
            if isValid {
                validationSpan.setData(value: "success", key: "validation.result")
                SentryInstrumentation.recordSuccess(validationSpan)
                
                appState.shippingAddress = address
                SentryInstrumentation.recordSuccess(span)
            } else {
                validationSpan.setData(value: "fail", key: "validation.result")
                SentryInstrumentation.recordFailure(validationSpan, error: ServiceError.validationError)
                SentryInstrumentation.recordFailure(span, error: ServiceError.validationError)
                throw ServiceError.validationError
            }
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Load shipping options
    func loadShippingOptions() async throws -> [ShippingOption] {
        guard let appState = appState else { return [] }
        
        // SENTRY INSTRUMENTATION: Load shipping options
        let span = SentryInstrumentation.startTransaction(
            name: "checkout.shipping_options.load",
            operation: "checkout.shipping_options.load"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: appState.shippingAddress.country, key: "shipping.destination_country")
        
        do {
            // Child span: Shipping quote API
            let quoteSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.shipping.quote",
                operation: "api.shipping.quote"
            )
            
            let options = try await backend.getShippingOptions(for: appState.shippingAddress)
            SentryInstrumentation.recordSuccess(quoteSpan)
            
            SentryInstrumentation.recordSuccess(span)
            return options
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Select shipping method
    func selectShippingMethod(_ option: ShippingOption) {
        guard let appState = appState else { return }
        
        appState.selectedShippingOption = option
        
        // Track selection in Sentry context
        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "method": option.method,
                "price": option.price
            ], key: "shipping")
        }
    }
    
    /// Calculate tax
    func calculateTax() async throws {
        guard let appState = appState,
              let shippingOption = appState.selectedShippingOption else {
            throw ServiceError.validationError
        }
        
        // SENTRY INSTRUMENTATION: Tax calculation
        let span = SentryInstrumentation.startTransaction(
            name: "checkout.tax.calculate",
            operation: "checkout.tax.calculate"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: "mock", key: "tax.provider")
        span.setData(value: appState.shippingAddress.country, key: "country")
        
        do {
            // Child span: Tax API
            let taxSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.tax",
                operation: "api.tax"
            )
            
            let subtotal = appState.cart.total + shippingOption.price
            let taxQuote = try await backend.calculateTax(
                amount: subtotal,
                address: appState.shippingAddress
            )
            
            SentryInstrumentation.recordSuccess(taxSpan)
            
            appState.taxQuote = taxQuote
            SentryInstrumentation.recordSuccess(span)
            
        } catch {
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
}

// MARK: - Payment Service

@MainActor
class PaymentService {
    private let backend = MockBackend.shared
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Select payment method
    func selectPaymentMethod(_ method: PaymentMethod) {
        guard let appState = appState else { return }
        
        // SENTRY INSTRUMENTATION: Payment method selection
        let span = SentryInstrumentation.startTransaction(
            name: "payment.method.select",
            operation: "payment.method.select"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: "mockpay", key: "payment.provider")
        span.setData(value: method.rawValue, key: "payment.method")
        
        appState.selectedPaymentMethod = method
        
        SentryInstrumentation.recordSuccess(span)
    }
    
    /// Authorize payment
    func authorizePayment(amount: Double) async throws -> PaymentIntent {
        guard let appState = appState else {
            throw ServiceError.validationError
        }
        
        // SENTRY INSTRUMENTATION: Payment authorization
        let span = SentryInstrumentation.startTransaction(
            name: "payment.authorize",
            operation: "payment.authorize"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: "mockpay", key: "payment.provider")
        span.setData(value: appState.selectedPaymentMethod.rawValue, key: "payment.method")
        span.setData(value: SentryInstrumentation.retryCountBucket(appState.paymentRetryCount), key: "retry.count_bucket")
        
        do {
            // Child span: Payment API
            let apiSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.payment",
                operation: "api.payment"
            )
            
            let intent = try await backend.createPaymentIntent(
                amount: amount,
                method: appState.selectedPaymentMethod
            )
            
            SentryInstrumentation.recordSuccess(apiSpan)
            
            // Determine payment flow
            let flow: PaymentFlow = intent.requiresAction ? .threeDSecure : .inApp
            span.setData(value: flow.rawValue, key: "payment.flow")
            span.setData(value: "success", key: "payment.result")
            
            appState.paymentIntent = intent
            SentryInstrumentation.recordSuccess(span)
            
            return intent
            
        } catch {
            span.setData(value: "fail", key: "payment.result")
            SentryInstrumentation.recordFailure(span, error: error)
            appState.paymentRetryCount += 1
            throw error
        }
    }
    
    /// Handle 3DS challenge
    func handle3DSChallenge(paymentIntentId: String) async throws {
        // SENTRY INSTRUMENTATION: 3DS challenge
        let span = SentryInstrumentation.startTransaction(
            name: "payment.3ds.challenge",
            operation: "payment.3ds.challenge"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: "mockpay", key: "payment.provider")
        span.setData(value: "3ds", key: "payment.flow")
        
        do {
            try await backend.confirm3DS(paymentIntentId: paymentIntentId)
            
            span.setData(value: "success", key: "payment.result")
            SentryInstrumentation.recordSuccess(span)
            
        } catch {
            span.setData(value: "fail", key: "payment.result")
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Capture payment (finalize)
    func capturePayment() async throws {
        // SENTRY INSTRUMENTATION: Payment capture
        let span = SentryInstrumentation.startTransaction(
            name: "payment.capture",
            operation: "payment.capture"
        )
        SentryInstrumentation.setCommonContext(span)
        
        // Simulate capture delay
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        SentryInstrumentation.recordSuccess(span)
    }
}

// MARK: - Order Service

@MainActor
class OrderService {
    private let backend = MockBackend.shared
    private weak var appState: AppState?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    /// Place order
    func placeOrder() async throws -> Order {
        guard let appState = appState,
              let shippingOption = appState.selectedShippingOption,
              let taxQuote = appState.taxQuote,
              let paymentIntent = appState.paymentIntent else {
            throw ServiceError.validationError
        }
        
        // SENTRY INSTRUMENTATION: Order placement
        let span = SentryInstrumentation.startTransaction(
            name: "order.place",
            operation: "order.place"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: appState.cart.itemCountBucket, key: "cart.item_count_bucket")
        span.setData(value: appState.cart.valueBucket, key: "order.value_bucket")
        span.setData(value: shippingOption.method, key: "shipping.method")
        
        do {
            // Child span: Create order API
            let orderSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "api.order.create",
                operation: "api.order.create"
            )
            
            let order = try await backend.createOrder(
                items: appState.cart.items,
                shippingAddress: appState.shippingAddress,
                shippingOption: shippingOption,
                tax: taxQuote,
                paymentIntentId: paymentIntent.id
            )
            
            SentryInstrumentation.recordSuccess(orderSpan)
            
            // Child span: Inventory reservation
            let inventorySpan = SentryInstrumentation.startChild(
                parent: span,
                name: "inventory.reserve",
                operation: "inventory.reserve"
            )
            
            let inventoryResult = order.status == "backorder" ? "backorder" : "reserved"
            inventorySpan.setData(value: inventoryResult, key: "inventory.result")
            inventorySpan.finishSuccess()
            
            // Child span: Send notifications
            let notificationSpan = SentryInstrumentation.startChild(
                parent: span,
                name: "notification.send",
                operation: "notification.send"
            )
            
            // Send notifications (fire and forget, don't block order)
            Task {
                try? await backend.sendNotification(
                    orderId: order.id,
                    channels: ["email", "push"]
                )
            }
            
            notificationSpan.setData(value: "email,push", key: "notification.channels")
            notificationSpan.finishSuccess()
            
            // Set order attributes
            span.setData(value: "success", key: "order.result")
            span.setData(value: inventoryResult, key: "inventory.result")
            span.setData(value: order.fulfillmentType, key: "fulfillment.type")
            
            appState.currentOrder = order
            
            // Clear cart after successful order
            appState.cart = Cart(items: [], promoApplied: false, promoDiscount: 0)
            appState.paymentRetryCount = 0
            
            SentryInstrumentation.recordSuccess(span)
            
            return order
            
        } catch {
            span.setData(value: "fail", key: "order.result")
            SentryInstrumentation.recordFailure(span, error: error)
            throw error
        }
    }
    
    /// Load order confirmation
    func loadOrderConfirmation(orderId: String) async throws {
        // SENTRY INSTRUMENTATION: Order confirmation load
        let span = SentryInstrumentation.startTransaction(
            name: "order.confirmation.load",
            operation: "order.confirmation.load"
        )
        SentryInstrumentation.setCommonContext(span)
        span.setData(value: orderId, key: "order.id")
        
        // Simulate loading confirmation details
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        SentryInstrumentation.recordSuccess(span)
    }
}


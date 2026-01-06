import Foundation

// MARK: - Domain Models

struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let currency: String
    let imageURL: String?
    let category: String
    let inStock: Bool
    
    var priceFormatted: String {
        String(format: "$%.2f", price)
    }
}

struct CartItem: Identifiable, Codable {
    let id: String
    let product: Product
    var quantity: Int
    
    var total: Double {
        product.price * Double(quantity)
    }
}

struct Cart: Codable {
    var items: [CartItem]
    var promoApplied: Bool
    var promoDiscount: Double
    
    var subtotal: Double {
        items.reduce(0) { $0 + $1.total }
    }
    
    var total: Double {
        subtotal - promoDiscount
    }
    
    var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    // Low-cardinality bucket for Sentry
    var itemCountBucket: String {
        switch itemCount {
        case 0: return "0"
        case 1: return "1"
        case 2...3: return "2-3"
        case 4...10: return "4-10"
        default: return "10+"
        }
    }
    
    var valueBucket: String {
        switch total {
        case 0..<25: return "$0-25"
        case 25..<100: return "$25-100"
        case 100..<250: return "$100-250"
        default: return "$250+"
        }
    }
}

struct Address: Codable {
    var street: String
    var city: String
    var state: String
    var zipCode: String
    var country: String
    
    var isValid: Bool {
        !street.isEmpty && !city.isEmpty && !zipCode.isEmpty
    }
}

struct ShippingOption: Identifiable, Codable {
    let id: String
    let method: String // standard, express, pickup
    let name: String
    let price: Double
    let estimatedDays: Int
}

struct TaxQuote: Codable {
    let amount: Double
    let rate: Double
    let provider: String
}

enum PaymentMethod: String, Codable {
    case card = "card"
    case applePay = "apple_pay"
    case paypal = "paypal"
}

enum PaymentFlow: String, Codable {
    case inApp = "in_app"
    case redirect = "redirect"
    case threeDSecure = "3ds"
}

struct PaymentIntent: Codable {
    let id: String
    let amount: Double
    let currency: String
    let status: String
    let requiresAction: Bool // For 3DS simulation
}

struct Order: Identifiable, Codable {
    let id: String
    let items: [CartItem]
    let shippingAddress: Address
    let shippingMethod: String
    let subtotal: Double
    let shippingCost: Double
    let tax: Double
    let total: Double
    let paymentMethod: String
    let status: String
    let createdAt: Date
    let fulfillmentType: String // ship, pickup, digital
}

// MARK: - Result Types

enum ServiceError: Error, LocalizedError {
    case networkError
    case validationError
    case providerError
    case fraudError
    case insufficientFundsError
    case notFoundError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Network connection failed"
        case .validationError: return "Validation failed"
        case .providerError: return "Service provider error"
        case .fraudError: return "Payment declined - fraud check"
        case .insufficientFundsError: return "Insufficient funds"
        case .notFoundError: return "Resource not found"
        case .unknownError: return "An unknown error occurred"
        }
    }
    
    // Low-cardinality failure category for Sentry
    var sentryCategory: String {
        switch self {
        case .networkError: return "network"
        case .validationError: return "validation"
        case .providerError: return "provider"
        case .fraudError: return "fraud"
        case .insufficientFundsError: return "insufficient_funds"
        case .notFoundError: return "not_found"
        case .unknownError: return "unknown"
        }
    }
}

// MARK: - Device & Network Info

struct DeviceInfo {
    static var deviceClass: String {
        #if targetEnvironment(simulator)
        return "mid"
        #else
        // Simple heuristic based on device model
        let model = UIDevice.current.model
        if model.contains("iPhone") {
            // In production, parse actual model number
            return "mid"
        }
        return "mid"
        #endif
    }
}

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var connectionType: String = "wifi"
    
    // In production, use NWPathMonitor
    // For this demo, we'll expose a toggle in debug settings
    func updateConnectionType(_ type: String) {
        connectionType = type
    }
}


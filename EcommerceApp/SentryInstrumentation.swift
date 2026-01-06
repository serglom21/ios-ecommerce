import Foundation
import Sentry

/// Centralized Sentry instrumentation helper
/// Ensures consistent span naming, operations, and attributes across the app
class SentryInstrumentation {
    
    // MARK: - Transaction & Span Creation
    
    /// Start a new transaction
    static func startTransaction(name: String, operation: String) -> Span {
        let transaction = SentrySDK.startTransaction(
            name: name,
            operation: operation,
            bindToScope: true
        )
        return transaction
    }
    
    /// Start a child span within a transaction
    static func startChild(parent: Span, name: String, operation: String) -> Span {
        return parent.startChild(operation: operation, description: name)
    }
    
    // MARK: - Common Context
    
    /// Apply common attributes to a span
    static func setCommonContext(_ span: Span) {
        // Environment
        span.setData(value: "dev", key: "environment")
        
        // Release & Build
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            span.setData(value: version, key: "release")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            span.setData(value: build, key: "build")
        }
        
        // Region (low-cardinality, no PII)
        let country = Locale.current.region?.identifier ?? "US"
        span.setData(value: country, key: "country")
        
        // Device class
        span.setData(value: DeviceInfo.deviceClass, key: "device.class")
        
        // Network type
        span.setData(value: NetworkMonitor.shared.connectionType, key: "network.type")
        
        // A/B variant (stubbed)
        let abVariant = UserDefaults.standard.string(forKey: "ab_variant") ?? "A"
        span.setData(value: abVariant, key: "ab.variant")
    }
    
    // MARK: - Result Recording
    
    /// Record success result on span
    static func recordSuccess(_ span: Span, additionalData: [String: Any] = [:]) {
        span.setData(value: "success", key: "result")
        for (key, value) in additionalData {
            span.setData(value: value, key: key)
        }
        span.finish(status: .ok)
    }
    
    /// Record failure result on span with normalized category
    static func recordFailure(_ span: Span, error: Error, category: String? = nil) {
        span.setData(value: "fail", key: "result")
        
        // Use error's category if it's a ServiceError
        let failureCategory: String
        if let serviceError = error as? ServiceError {
            failureCategory = serviceError.sentryCategory
        } else {
            failureCategory = category ?? "unknown"
        }
        
        span.setData(value: failureCategory, key: "failure_category")
        span.finish(status: .internalError)
    }
    
    /// Record cancellation
    static func recordCancellation(_ span: Span) {
        span.setData(value: "cancel", key: "result")
        span.finish(status: .cancelled)
    }
    
    // MARK: - Navigation Tracking
    
    /// Track route changes
    static func trackNavigation(from: String, to: String) {
        let span = startTransaction(name: "route.change", operation: "navigation")
        setCommonContext(span)
        span.setData(value: from, key: "route.from")
        span.setData(value: to, key: "route.to")
        span.finish(status: .ok)
    }
    
    // MARK: - Attribute Helpers
    
    /// Get result count bucket (low-cardinality)
    static func resultCountBucket(_ count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1...10: return "1-10"
        case 11...50: return "11-50"
        default: return "50+"
        }
    }
    
    /// Get payload size bucket (low-cardinality)
    static func payloadSizeBucket(_ sizeInBytes: Int) -> String {
        switch sizeInBytes {
        case 0..<10_240: return "0-10KB"
        case 10_240..<102_400: return "10-100KB"
        default: return "100KB+"
        }
    }
    
    /// Get retry count bucket (low-cardinality)
    static func retryCountBucket(_ retries: Int) -> String {
        switch retries {
        case 0: return "0"
        case 1: return "1"
        default: return "2+"
        }
    }
}

// MARK: - Convenience Extensions

extension Span {
    /// Finish span with a success status
    func finishSuccess() {
        self.finish(status: .ok)
    }
    
    /// Finish span with failure status
    func finishFailure() {
        self.finish(status: .internalError)
    }
}


# Sentry Instrumentation Guide

This document explains the instrumentation patterns used in this e-commerce app and how to apply them to your own projects.

## 📐 Core Principles

### 1. Consistent Naming Convention

**Transaction/Span Names**: Use dot notation to represent hierarchy
- Format: `resource.action` or `category.subcategory.action`
- Examples:
  - `search.query`
  - `product.detail.load`
  - `cart.add_item`
  - `payment.authorize`
  - `order.place`

**Operation Names**: Match the domain of work being done
- `app.startup` - Application initialization
- `navigation` - Route changes
- `ui.render.*` - UI rendering work
- `api.*` - Network API calls
- `cache` - Cache operations
- `pricing` - Price calculations
- `checkout.*` - Checkout flow steps
- `payment.*` - Payment operations
- `order.*` - Order operations
- `notification.*` - Notification sending

### 2. Low-Cardinality Attributes Only

**Why?** High-cardinality attributes (like user IDs, order IDs, timestamps) make it impossible to aggregate and query data effectively.

**Always Use Buckets for Numeric Values:**

```swift
// ❌ BAD: High cardinality
span.setData(value: 127, key: "cart.item_count")
span.setData(value: 549.99, key: "order.value")

// ✅ GOOD: Low cardinality buckets
span.setData(value: "10+", key: "cart.item_count_bucket")
span.setData(value: "$250+", key: "order.value_bucket")
```

**Use Enums for Categorical Data:**

```swift
// ✅ GOOD: Fixed set of values
span.setData(value: "card", key: "payment.method") // card|apple_pay|paypal
span.setData(value: "3ds", key: "payment.flow")    // in_app|redirect|3ds
span.setData(value: "fraud", key: "payment.failure_category")
```

### 3. Never Include PII (Personally Identifiable Information)

**Examples of PII to Avoid:**
- ❌ Email addresses
- ❌ Names
- ❌ Phone numbers
- ❌ Full addresses (street, apartment #)
- ❌ Payment card numbers
- ❌ Raw search queries (may contain names/emails)
- ❌ Error messages with sensitive data

**Safe Alternatives:**
- ✅ User type (guest vs logged_in)
- ✅ Country/region only (no city/street)
- ✅ Payment method type (not card number)
- ✅ Search result count (not query text)
- ✅ Error category (not full message)

## 🛠️ Implementation Patterns

### Pattern 1: Simple Transaction

For a single operation without sub-steps:

```swift
func simpleOperation() async throws {
    // Start transaction
    let span = SentryInstrumentation.startTransaction(
        name: "resource.action",
        operation: "operation.type"
    )
    
    // Set common context (environment, device, network, etc.)
    SentryInstrumentation.setCommonContext(span)
    
    // Add operation-specific attributes
    span.setData(value: "some_value", key: "attribute.name")
    
    do {
        // Perform work
        let result = try await doWork()
        
        // Record success
        SentryInstrumentation.recordSuccess(span)
        
    } catch {
        // Record failure with normalized category
        SentryInstrumentation.recordFailure(span, error: error)
        throw error
    }
}
```

### Pattern 2: Transaction with Child Spans

For operations with multiple distinct steps:

```swift
func complexOperation() async throws {
    // Parent transaction
    let transaction = SentryInstrumentation.startTransaction(
        name: "resource.complex_action",
        operation: "operation.type"
    )
    SentryInstrumentation.setCommonContext(transaction)
    
    do {
        // Child span 1: API call
        let apiSpan = SentryInstrumentation.startChild(
            parent: transaction,
            name: "api.fetch",
            operation: "api.fetch"
        )
        
        let data = try await fetchFromAPI()
        apiSpan.setData(value: data.count, key: "result_count")
        SentryInstrumentation.recordSuccess(apiSpan)
        
        // Child span 2: Processing
        let processSpan = SentryInstrumentation.startChild(
            parent: transaction,
            name: "processing.compute",
            operation: "processing.compute"
        )
        
        let result = processData(data)
        SentryInstrumentation.recordSuccess(processSpan)
        
        // Record parent success
        transaction.setData(value: result.count, key: "final_count")
        SentryInstrumentation.recordSuccess(transaction)
        
    } catch {
        SentryInstrumentation.recordFailure(transaction, error: error)
        throw error
    }
}
```

### Pattern 3: Optional Child Spans

For non-critical steps that shouldn't fail the parent:

```swift
func operationWithOptionalSteps() async throws {
    let transaction = SentryInstrumentation.startTransaction(
        name: "resource.action",
        operation: "operation.type"
    )
    SentryInstrumentation.setCommonContext(transaction)
    
    do {
        // Critical step
        let result = try await criticalOperation()
        
        // Optional step - don't throw if it fails
        let recoSpan = SentryInstrumentation.startChild(
            parent: transaction,
            name: "optional.recommendations",
            operation: "api.recommendations"
        )
        
        do {
            let recommendations = try await getRecommendations()
            recoSpan.setData(value: recommendations.count, key: "count")
            SentryInstrumentation.recordSuccess(recoSpan)
        } catch {
            // Log failure but don't propagate
            SentryInstrumentation.recordFailure(recoSpan, error: error)
        }
        
        SentryInstrumentation.recordSuccess(transaction)
        
    } catch {
        SentryInstrumentation.recordFailure(transaction, error: error)
        throw error
    }
}
```

### Pattern 4: Navigation Tracking

Track route changes to understand user flow:

```swift
func navigateToScreen(_ screenName: String) {
    let previousScreen = currentScreen
    currentScreen = screenName
    
    // Track navigation
    SentryInstrumentation.trackNavigation(
        from: previousScreen,
        to: screenName
    )
}
```

## 📊 Attribute Reference

### Universal Attributes (Set via `setCommonContext`)

Applied to every span automatically:

| Attribute | Type | Values | Description |
|-----------|------|--------|-------------|
| `environment` | string | dev, staging, production | Deployment environment |
| `release` | string | 1.0.0 | App version |
| `build` | string | 123 | Build number |
| `country` | string | US, CA, UK, etc. | User's country (from Locale) |
| `device.class` | string | low, mid, high | Device performance class |
| `network.type` | string | wifi, cellular, offline | Connection type |
| `ab.variant` | string | A, B, C, etc. | A/B test variant |

### Domain-Specific Attributes

#### Search
| Attribute | Values | Usage |
|-----------|--------|-------|
| `search.backend` | mock, algolia, elasticsearch | Which search service |
| `search.result_count_bucket` | 0, 1-10, 11-50, 50+ | Number of results |

#### Cart
| Attribute | Values | Usage |
|-----------|--------|-------|
| `cart.item_count_bucket` | 0, 1, 2-3, 4-10, 10+ | Items in cart |
| `cart.value_bucket` | $0-25, $25-100, $100-250, $250+ | Cart total |
| `promo.applied` | true, false | Promo code used |
| `currency` | USD, EUR, GBP, etc. | Currency code |

#### Checkout
| Attribute | Values | Usage |
|-----------|--------|-------|
| `checkout.type` | guest, logged_in | User authentication status |
| `validation.result` | success, fail | Address validation outcome |
| `shipping.destination_country` | US, CA, UK, etc. | Where shipping to |
| `shipping.method` | standard, express, pickup | Selected shipping |
| `tax.provider` | mock, avalara, taxjar | Tax calculation service |

#### Payment
| Attribute | Values | Usage |
|-----------|--------|-------|
| `payment.provider` | stripe, braintree, mockpay | Payment processor |
| `payment.method` | card, apple_pay, paypal, etc. | How paying |
| `payment.flow` | in_app, redirect, 3ds | Payment UX flow |
| `payment.result` | success, fail, cancel | Outcome |
| `payment.failure_category` | validation, network, provider, fraud, insufficient_funds, unknown | Why it failed |
| `retry.count_bucket` | 0, 1, 2+ | Retry attempts |

#### Order
| Attribute | Values | Usage |
|-----------|--------|-------|
| `order.result` | success, fail | Order creation outcome |
| `inventory.result` | reserved, backorder, fail | Inventory check |
| `fulfillment.type` | ship, pickup, digital | How delivering |
| `notification.channels` | email, sms, push | Which notifications sent |

## 🎯 Common Queries & Use Cases

### Performance Analysis

**Find slow payment authorizations by network type:**
```
transaction.op:payment.authorize AND transaction.duration:>2s
GROUP BY network.type
```

**Compare search performance across A/B variants:**
```
transaction.op:search.query
GROUP BY ab.variant
AGGREGATE avg(transaction.duration)
```

### Conversion Funnel

**Track checkout abandonment:**
```
Step 1: checkout.start (operation:checkout.start)
Step 2: checkout.address.submit (operation:checkout.address.submit)
Step 3: checkout.shipping_options.load
Step 4: payment.authorize
Step 5: order.place
```

**High-value cart abandonment:**
```
checkout.start AND cart.value_bucket:$250+
BUT NOT order.place
```

### Error Analysis

**Payment failures by category:**
```
payment.result:fail
GROUP BY payment.failure_category
```

**Orders with inventory issues:**
```
order.place AND inventory.result:backorder
GROUP BY fulfillment.type
```

**3DS challenge failure rate:**
```
payment.3ds.challenge
AGGREGATE success_rate(payment.result:success)
```

### Business Metrics

**Average cart value by user type:**
```
cart.add_item
GROUP BY user.type (guest vs logged_in)
AGGREGATE count BY cart.value_bucket
```

**Payment method preferences:**
```
payment.authorize
GROUP BY payment.method, country
```

**Shipping method selection:**
```
checkout.shipping_options.load
GROUP BY shipping.method, shipping.destination_country
```

## 🚨 Anti-Patterns to Avoid

### ❌ High Cardinality

```swift
// BAD: Creates millions of unique values
span.setData(value: orderID, key: "order.id")
span.setData(value: userEmail, key: "user.email")
span.setData(value: timestamp, key: "created_at")
```

### ❌ Including PII

```swift
// BAD: Exposes sensitive data
span.setData(value: "john@example.com", key: "email")
span.setData(value: "John Smith", key: "customer_name")
span.setData(value: "123 Main St", key: "address")
```

### ❌ Not Finishing Spans

```swift
// BAD: Span never finishes
func doWork() {
    let span = startTransaction(name: "work", operation: "work")
    
    // If this throws, span is never finished!
    try riskyOperation()
    
    span.finish()
}

// GOOD: Always finish spans
func doWork() throws {
    let span = startTransaction(name: "work", operation: "work")
    
    do {
        try riskyOperation()
        SentryInstrumentation.recordSuccess(span)
    } catch {
        SentryInstrumentation.recordFailure(span, error: error)
        throw error
    }
}
```

### ❌ Too Many Spans

```swift
// BAD: Creating spans for trivial operations adds overhead
for item in items {
    let span = startChild(parent: parent, name: "process.item", operation: "process")
    processItem(item)
    span.finish()
}

// GOOD: One span for the collection
let span = startChild(parent: parent, name: "process.items", operation: "process")
for item in items {
    processItem(item)
}
span.setData(value: items.count, key: "item_count")
span.finish()
```

## 📈 Advanced Techniques

### Dynamic Sampling

Adjust sample rate based on transaction type:

```swift
SentrySDK.start { options in
    options.tracesSampleRate = 1.0 // Default
    
    options.tracesSampler = { context in
        // Sample 100% of payment transactions
        if context.transactionContext.name.contains("payment") {
            return 1.0
        }
        
        // Sample 10% of search queries
        if context.transactionContext.operation == "search.query" {
            return 0.1
        }
        
        // Default 20%
        return 0.2
    }
}
```

### Distributed Tracing

If calling backend services, propagate trace context:

```swift
let transaction = SentrySDK.startTransaction(...)

var request = URLRequest(url: url)

// Add Sentry trace header
if let traceId = transaction.toTraceHeader() {
    request.setValue(traceId.value(), forHTTPHeaderField: "sentry-trace")
}

// Make request
let (data, _) = try await URLSession.shared.data(for: request)
```

### Custom Measurements

Add timing measurements for specific operations:

```swift
let span = startChild(...)

let start = Date()
let result = await expensiveOperation()
let duration = Date().timeIntervalSince(start)

// Add custom measurement
span.setMeasurement(name: "custom.duration", value: duration, unit: MeasurementUnitDuration.second)

span.finish()
```

## 🎓 Summary

**Golden Rules:**
1. ✅ Use consistent naming conventions
2. ✅ Always use low-cardinality attributes
3. ✅ Never include PII
4. ✅ Always finish spans (use try/catch/defer)
5. ✅ Set common context on every span
6. ✅ Normalize errors into categories
7. ✅ Use child spans for complex operations
8. ✅ Make spans represent business operations, not just code structure

**This instrumentation gives you:**
- 🎯 Precise performance insights at every step
- 📊 Business metrics alongside technical metrics
- 🐛 Fast root cause analysis when things break
- 💰 Optimization opportunities based on real user behavior
- 🔍 Ability to slice by any relevant dimension

Now go instrument your app and ship with confidence! 🚀


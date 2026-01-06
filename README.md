# iOS E-Commerce App with Sentry Observability

A fully-functional iOS e-commerce application built with SwiftUI and comprehensive Sentry instrumentation for production-grade observability.

## 🎯 Overview

This app demonstrates **first-class observability** using Sentry custom spans and attributes. Every critical user flow is instrumented to surface:
- Which steps are slow or failing
- Key business metrics (cart value, conversion funnel)
- Technical context (network type, device class, retry counts)
- All with **low-cardinality attributes** and **no PII**

## 🏗️ Architecture

### Clean Architecture
- **AppState**: Single source of truth for app state
- **Services**: Business logic layer with full Sentry instrumentation
  - `CatalogService`: Product search and details
  - `CartService`: Shopping cart management
  - `CheckoutService`: Address validation, shipping, and tax
  - `PaymentService`: Payment authorization and 3DS handling
  - `OrderService`: Order placement and confirmation
- **Views**: SwiftUI views for each screen
- **MockBackend**: In-memory backend simulator with configurable latency and error injection

### Sentry Integration
- **SentryInstrumentation**: Centralized helper for consistent span naming, operations, and attributes
- **Automatic context**: Session ID, device class, network type, country, A/B variant
- **Manual instrumentation**: Every critical flow has custom spans with relevant attributes

## 📱 Features

### Core E-Commerce Flows
1. **Browse & Search**
   - Featured products on home screen
   - Search with instant results
   - Product detail with recommendations

2. **Shopping Cart**
   - Add/remove/update items
   - Promo code toggle
   - Real-time price calculation

3. **Checkout**
   - 3-step process: Address → Shipping → Review
   - Address validation
   - Multiple shipping options
   - Tax calculation

4. **Payment**
   - Multiple payment methods (Card, Apple Pay, PayPal)
   - 3D Secure simulation
   - Retry handling
   - Payment capture

5. **Order Confirmation**
   - Order summary
   - Inventory status
   - Fulfillment details

### Debug & Testing
- **Debug Settings Screen**:
  - Latency profiles (Fast/Normal/Slow)
  - Network type toggle (WiFi/Cellular/Offline)
  - Failure injection per endpoint
  - A/B variant switcher
  - Sentry configuration display

## 🔍 Sentry Instrumentation

### Transaction & Span Hierarchy

#### 1. App Startup
```
app.startup (operation: app.startup)
├─ Attributes: app.startup_type = cold
```

#### 2. Search Flow
```
search.query (operation: search.query)
├─ api.search (operation: api.search)
│  └─ Attributes: search.result_count_bucket
└─ ui.render.results (operation: ui.render.results)
   └─ Attributes: search.backend = mock
```

#### 3. Product Detail
```
product.detail.load (operation: product.detail.load)
├─ api.product.detail (operation: api.product.detail)
└─ api.recommendations (operation: api.recommendations)
   └─ Attributes: feature.reco_enabled
```

#### 4. Cart Operations
```
cart.add_item (operation: cart.add_item)
├─ api.cart.add (operation: api.cart.add)
└─ pricing.recalc (operation: pricing.recalc)
   └─ Attributes: cart.item_count_bucket, cart.value_bucket, promo.applied, currency
```

#### 5. Checkout Flow
```
checkout.start (operation: checkout.start)
└─ Attributes: checkout.type (guest|logged_in)

checkout.address.submit (operation: checkout.address.submit)
└─ api.address.validate (operation: api.address.validate)
   └─ Attributes: validation.result, address.country

checkout.shipping_options.load (operation: checkout.shipping_options.load)
└─ api.shipping.quote (operation: api.shipping.quote)
   └─ Attributes: shipping.destination_country

checkout.tax.calculate (operation: checkout.tax.calculate)
└─ api.tax (operation: api.tax)
   └─ Attributes: tax.provider, country
```

#### 6. Payment Flow (Most Critical)
```
payment.authorize (operation: payment.authorize)
└─ api.payment (operation: api.payment)
   └─ Attributes:
      - payment.provider = mockpay
      - payment.method (card|apple_pay|paypal)
      - payment.flow (in_app|3ds)
      - payment.result (success|fail)
      - payment.failure_category
      - retry.count_bucket

payment.3ds.challenge (operation: payment.3ds.challenge)
└─ Attributes: payment.flow = 3ds, payment.result

payment.capture (operation: payment.capture)
```

#### 7. Order Placement
```
order.place (operation: order.place)
├─ api.order.create (operation: api.order.create)
├─ inventory.reserve (operation: inventory.reserve)
│  └─ Attributes: inventory.result (reserved|backorder|fail)
└─ notification.send (operation: notification.send)
   └─ Attributes: notification.channels, fulfillment.type
```

### Common Attributes (Applied to All Spans)

**Environment & Release**
- `environment`: "dev"
- `release`: "1.0+1"
- `build`: "1"

**User Context**
- `user.type`: guest | logged_in (no user ID - no PII)

**Session & Location**
- `session.id`: UUID per app launch
- `country`: US (from Locale, not GPS)

**Device & Network**
- `device.class`: low | mid | high
- `network.type`: wifi | cellular | offline

**A/B Testing**
- `ab.variant`: A | B

### Low-Cardinality Attribute Buckets

**Cart Metrics**
- `cart.item_count_bucket`: 0 | 1 | 2-3 | 4-10 | 10+
- `cart.value_bucket`: $0-25 | $25-100 | $100-250 | $250+

**Search Results**
- `search.result_count_bucket`: 0 | 1-10 | 11-50 | 50+

**Retry Counts**
- `retry.count_bucket`: 0 | 1 | 2+

**Payload Size**
- `payload.size_bucket`: 0-10KB | 10-100KB | 100KB+

### Error Handling & Failure Categories

All errors are normalized into low-cardinality categories:
- `validation`: Input validation failures
- `network`: Network connectivity issues
- `provider`: Third-party service errors
- `fraud`: Payment fraud checks
- `insufficient_funds`: Payment declined
- `not_found`: Resource not found
- `unknown`: Unexpected errors

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Sentry account (get a free account at [sentry.io](https://sentry.io))

### Setup

1. **Clone the repository**
   ```bash
   cd /Users/sergiolombana/Documents/ios-ecommerce
   ```

2. **Configure Sentry DSN**
   
   Open `EcommerceApp/EcommerceAppApp.swift` and replace the DSN:
   ```swift
   options.dsn = "YOUR_SENTRY_DSN_HERE"
   ```

3. **Install Dependencies**
   
   The project uses Swift Package Manager. Xcode will automatically resolve the Sentry SDK dependency when you first open the project.

4. **Build & Run**
   ```bash
   open EcommerceApp.xcodeproj
   ```
   - Select a simulator or device
   - Press ⌘+R to build and run

### Testing Scenarios

1. **Happy Path**: 
   - Search for a product
   - Add to cart
   - Complete checkout
   - Process payment
   - View order confirmation

2. **Slow Network**:
   - Go to Debug tab
   - Set Latency Profile to "Slow"
   - Observe span durations in Sentry

3. **Payment Failures**:
   - Enable "Payment" failure injection in Debug settings
   - Attempt checkout
   - Observe retry behavior and failure categories in Sentry

4. **3D Secure Flow**:
   - Process payment (30% chance of 3DS)
   - When prompted, verify to continue

5. **Network Offline**:
   - Toggle "Simulate Offline" in Debug settings
   - Try any operation
   - Observe network error spans

## 📊 Viewing Traces in Sentry

1. **Navigate to Performance → Traces**
2. **Filter by operation**:
   - `payment.authorize` - See payment success/failure rates
   - `checkout.*` - Analyze checkout funnel
   - `order.place` - Track order completion
   - `search.query` - Monitor search performance

3. **Key Queries**:
   ```
   payment.result:fail AND payment.failure_category:fraud
   cart.value_bucket:$250+ AND checkout.type:guest
   payment.flow:3ds AND payment.result:success
   inventory.result:backorder
   network.type:cellular AND transaction.duration:>2s
   ```

4. **Dashboards**:
   - Create custom dashboards tracking:
     - Payment success rate by method
     - Cart abandonment at each step
     - Average transaction duration by network type
     - Order value distribution
     - 3DS challenge rate

## 🏗️ Project Structure

```
EcommerceApp/
├── EcommerceAppApp.swift          # App entry point + Sentry init
├── AppState.swift                 # Central state management
├── Models.swift                   # Domain models
├── SentryInstrumentation.swift    # Sentry helper utilities
├── MockBackend.swift              # Mock API with latency/error injection
├── Services.swift                 # Business logic services
├── ContentView.swift              # Main navigation
├── Views/
│   ├── HomeView.swift            # Featured products
│   ├── SearchView.swift          # Product search
│   ├── ProductDetailView.swift   # Product details + recommendations
│   ├── CartView.swift            # Shopping cart
│   ├── CheckoutView.swift        # 3-step checkout
│   ├── PaymentView.swift         # Payment processing
│   ├── OrderConfirmationView.swift # Order confirmation
│   └── DebugSettingsView.swift   # Debug controls
└── Assets.xcassets               # Asset catalog
```

## 🎓 Key Learnings

### Best Practices Demonstrated

1. **Consistent Span Naming**
   - Use dot notation: `resource.action`
   - Operation types match the domain: `api.*`, `ui.*`, `payment.*`

2. **Attribute Hygiene**
   - Always use low-cardinality buckets for numeric values
   - Never include PII (emails, names, addresses)
   - Use enums for categorical data

3. **Error Normalization**
   - Map all errors to a small set of failure categories
   - Include category in span data for easy filtering

4. **Nested Spans**
   - Parent span represents the business operation
   - Child spans show the critical path (API, rendering, validation)

5. **Context Enrichment**
   - Set common context once per span
   - Include environment, device, network info
   - Attach session and A/B variant

6. **Span Lifecycle**
   - Always finish spans (success/failure/cancel)
   - Use try/catch/defer to ensure cleanup
   - Don't leave spans open when navigating away

## 🐛 Troubleshooting

### Spans Not Appearing in Sentry
- Check DSN is configured correctly
- Verify `tracesSampleRate` is > 0
- Ensure you're on a supported iOS version (17.0+)
- Check Xcode console for Sentry SDK logs

### Build Errors
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Reset package caches: File → Packages → Reset Package Caches
- Ensure Swift version is 5.9+

### Network Errors in Simulator
- Check "Simulate Offline" is disabled in Debug settings
- Verify simulator has network access
- Try resetting simulator: Device → Erase All Content and Settings

## 📝 License

MIT License - feel free to use this code for learning and production projects.

## 🙏 Acknowledgments

Built with:
- [Sentry iOS SDK](https://github.com/getsentry/sentry-cocoa)
- SwiftUI
- Swift async/await

---

**Happy Coding with World-Class Observability! 🚀**


# Quick Start Guide

Get up and running in 5 minutes! 🚀

## ✅ Pre-Flight Checklist

### 1. Prerequisites
- [ ] Xcode 15.0+ installed
- [ ] macOS with iOS 17.0+ simulator
- [ ] Sentry account (free at [sentry.io](https://sentry.io))

### 2. Get Your Sentry DSN

1. Go to [sentry.io](https://sentry.io)
2. Create a new project (or use existing)
3. Select **iOS** as platform
4. Copy your DSN (looks like: `https://abc123@o123.ingest.sentry.io/456`)

### 3. Configure the App

Open `EcommerceApp/EcommerceAppApp.swift` and replace line 13:

```swift
// REPLACE THIS:
options.dsn = "https://examplePublicKey@o0.ingest.sentry.io/0"

// WITH YOUR DSN:
options.dsn = "YOUR_ACTUAL_DSN_HERE"
```

### 4. Build & Run

```bash
cd /Users/sergiolombana/Documents/ios-ecommerce
open EcommerceApp.xcodeproj
```

In Xcode:
- Select a simulator (iPhone 15 Pro recommended)
- Press ⌘+R or click the Play button
- Wait for build to complete (~30 seconds first time)

### 5. Test the App

#### Basic Flow (2 minutes)
1. **Home Screen** appears → Browse featured products
2. Tap **Search** tab → Search for "headphones"
3. Tap any product → View details
4. Tap **Add to Cart** → Confirm added
5. Tap **Cart** tab → See your item
6. Tap **Proceed to Checkout**
7. Fill address (any test data):
   - Street: 123 Main St
   - City: San Francisco
   - State: CA
   - ZIP: 94102
   - Country: US
8. Tap **Continue to Shipping**
9. Select any shipping method
10. Tap **Continue to Review**
11. Tap **Continue to Payment**
12. Select payment method (Card is default)
13. Tap **Pay Now**
14. If prompted for 3DS, tap **Verify**
15. **Order Confirmation** screen appears! 🎉

### 6. View Traces in Sentry

1. Go to your Sentry project
2. Navigate to **Performance** → **Traces**
3. You should see transactions like:
   - `app.startup`
   - `search.query`
   - `product.detail.load`
   - `cart.add_item`
   - `checkout.start`
   - `payment.authorize`
   - `order.place`

4. Click any transaction to see:
   - Duration breakdown
   - Child spans (API calls, rendering)
   - All attributes we set
   - Network waterfall

## 🧪 Test Scenarios

### Scenario 1: Slow Network
**Purpose**: See how latency affects user experience

1. Tap **Debug** tab
2. Set **Latency Profile** to **Slow (1-3s)**
3. Go back and search for something
4. Notice the delay
5. Check Sentry → See longer span durations

**Expected**: All spans show 1-3s durations

---

### Scenario 2: Payment Failure
**Purpose**: Test error handling and retry logic

1. Tap **Debug** tab
2. Enable **Payment** under Failure Injection
3. Add item to cart and complete checkout
4. Attempt payment
5. See error message
6. Try again (retry increments)
7. Check Sentry → See failed payment spans

**Expected**: 
- `payment.result: fail`
- `payment.failure_category: provider` (or fraud/insufficient_funds)
- `retry.count_bucket: 1` on second attempt

---

### Scenario 3: 3D Secure Flow
**Purpose**: Observe 3DS authentication path

1. Complete checkout normally
2. ~30% chance of 3DS prompt
3. Tap **Verify** to confirm
4. Complete order
5. Check Sentry → See `payment.3ds.challenge` span

**Expected**:
- `payment.flow: 3ds`
- Additional `payment.3ds.challenge` span
- Longer total payment duration

---

### Scenario 4: Cart Abandonment
**Purpose**: Track where users drop off

1. Add items to cart
2. Start checkout
3. Close app (⌘+W or swipe up)
4. Check Sentry → See checkout spans without order.place

**Expected**: Incomplete funnel data shows abandonment

---

### Scenario 5: A/B Testing
**Purpose**: Compare performance across variants

1. Complete full checkout flow
2. Note time to complete
3. Tap **Debug** → Change **A/B Variant** to B
4. Complete checkout again
5. In Sentry, filter by `ab.variant:A` vs `ab.variant:B`

**Expected**: Can segment performance by variant

---

### Scenario 6: Network Offline
**Purpose**: Test offline error handling

1. Tap **Debug** tab
2. Enable **Simulate Offline**
3. Try any operation (search, add to cart, etc.)
4. See error messages
5. Check Sentry → See network error spans

**Expected**:
- `failure_category: network`
- All operations fail immediately

## 📊 Key Metrics to Watch in Sentry

### Performance Queries

**Slowest operations:**
```
Sort by: p95(transaction.duration) DESC
```

**Search performance by network:**
```
transaction.op:search.query
Group by: network.type
```

**Payment success rate:**
```
transaction.op:payment.authorize
Filter: payment.result:success vs fail
```

**Checkout funnel:**
```
checkout.start → checkout.address.submit → 
checkout.shipping_options.load → payment.authorize → order.place
```

### Business Queries

**High-value carts:**
```
cart.value_bucket:$250+
```

**Guest vs logged in conversion:**
```
checkout.type:guest vs logged_in
Compare: count(order.place)
```

**3DS challenge rate:**
```
payment.3ds.challenge
Calculate: count / count(payment.authorize) * 100
```

**Inventory backorders:**
```
inventory.result:backorder
Group by: fulfillment.type
```

## 🐛 Troubleshooting

### "Cannot find module 'Sentry'"
**Solution**: Wait for SPM to resolve dependencies (30-60 seconds), then rebuild

### No traces appearing in Sentry
**Solution**: 
1. Check DSN is correct
2. Check internet connection
3. Check Sentry project is iOS platform
4. Wait 30 seconds for data to appear

### Simulator crashes
**Solution**: 
1. Reset simulator: Device → Erase All Content and Settings
2. Clean build: Product → Clean Build Folder (⇧⌘K)
3. Rebuild

### Build errors
**Solution**:
1. Xcode → File → Packages → Reset Package Caches
2. Close and reopen Xcode
3. Clean build folder
4. Rebuild

## 🎯 Next Steps

1. ✅ **Explore the code**: Open `SentryInstrumentation.swift` to see helper functions
2. ✅ **Read the guides**:
   - `README.md` - Full documentation
   - `SENTRY_INSTRUMENTATION_GUIDE.md` - Deep dive on patterns
   - `PROJECT_SUMMARY.md` - What was built
3. ✅ **Create dashboards**: Build custom Sentry dashboards with your favorite queries
4. ✅ **Set up alerts**: Get notified when payment failure rate spikes
5. ✅ **Customize**: Modify the app to match your use case

## 🎓 Learning Path

### Beginner (You are here!)
- [x] Run the app
- [x] Complete a checkout
- [ ] View traces in Sentry
- [ ] Test one failure scenario

### Intermediate
- [ ] Understand all span types
- [ ] Create custom Sentry queries
- [ ] Modify an attribute
- [ ] Add a new span

### Advanced
- [ ] Build a custom dashboard
- [ ] Set up alerts
- [ ] Implement distributed tracing
- [ ] Add custom measurements

## 🚀 You're Ready!

You now have a fully-instrumented e-commerce app running locally with Sentry traces flowing in. 

Explore, experiment, and learn how production-grade observability works! 🎉

---

**Questions?** Check the comprehensive guides or the inline code comments.


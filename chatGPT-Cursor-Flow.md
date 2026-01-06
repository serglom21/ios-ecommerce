
You said:
if you are an engineer working on an e-commerce app and want to use Sentry to custom instrument those critical flows to surface insights around what parts are slow or failing using custom spans and attributes, which spans or attributes would you custom instrument?
ChatGPT said:
Here’s what I’d custom-instrument in an e-commerce app if the goal is: quickly see which step is slow/failing, and be able to slice it by user + cart + payment + fulfillment context without blowing up cardinality.

The spans I’d add (by critical flow)
1) App start + navigation to shopping
Spans

app.startup (cold/warm split)

route.change / navigation (screen-to-screen)

api.products.list

api.categories.list

ui.render.grid (or key component renders)

Attributes

app.startup_type: cold|warm

route.from, route.to (low-cardinality route names)

device.class: low|mid|high

network.type: wifi|cellular|offline

cache.hit: true|false

2) Browse/search → product discovery
Spans

search.query (wrap end-to-end search interaction)

child: api.search

child: ui.render.results

product.detail.load

child: api.product.detail

child: api.recommendations (if any)

child: ui.image.load (only if it’s a known pain point)

Attributes

search.backend: elastic|algolia|…

search.result_count_bucket: 0|1-10|11-50|50+ (bucket, don’t log exact counts)

product.id only if safe/allowed and if you control cardinality (often better: hash or omit)

ab.variant: A|B|C (low-cardinality)

feature.reco_enabled: true|false

3) Add to cart / update cart (high value, frequent)
Spans

cart.add_item

child: api.cart.add

child: pricing.recalc

cart.update_quantity

cart.remove_item

cart.load

Attributes

cart.item_count_bucket: 0|1|2-3|4-10|10+

cart.value_bucket: $0-25|25-100|100-250|250+ (bucketed)

promo.applied: true|false

currency: USD|CAD|…

pricing.source: cache|service|edge

4) Checkout start → address/shipping/taxes (where funnels break)
Spans

checkout.start

checkout.identity (login/guest/SSO)

checkout.address.submit

child: api.address.validate

checkout.shipping_options.load

child: api.shipping.quote

checkout.tax.calculate

child: api.tax

Attributes

checkout.type: guest|logged_in

shipping.destination_country (country only; avoid full address)

shipping.method_selected: standard|express|pickup (coarse)

tax.provider: avalara|internal|…

validation.result: success|fail

5) Payment (the most important custom instrumentation)
Spans

payment.method.select

payment.intent.create / payment.authorize

payment.3ds.challenge (if applicable)

payment.capture

payment.confirmation.render

Attributes

payment.provider: stripe|adyen|paypal|…

payment.method: card|apple_pay|google_pay|paypal|…

payment.flow: redirect|in_app|3ds

payment.result: success|fail|cancel

payment.failure_category: validation|network|provider|fraud|insufficient_funds|unknown (normalize!)

retry.count_bucket: 0|1|2+

Tip: store provider error code in a normalized way (e.g. mapped to a small set), not raw messages.

6) Place order → post-payment fulfillment + confirmation
Spans

order.place

child: api.order.create

child: inventory.reserve

child: notification.send (email/SMS)

order.confirmation.load

order.status.poll (if you poll)

Attributes

order.result: success|fail

inventory.result: reserved|backorder|fail

fulfillment.type: ship|pickup|digital

notification.channels: email|sms|push (coarse)

Cross-cutting attributes I’d add almost everywhere
Performance context (slice “why slow”)
network.type, network.rtt_bucket, network.downlink_bucket

cache.hit

payload.size_bucket

retry.count_bucket

cdn.pop (if applicable)

Release & experiment context (slice regressions)
release / build

environment: prod|staging

ab.variant

feature.flag.<name> (only for a handful of important flags)

User/session context (debug without PII)
user.type: guest|logged_in

session.id (uuid)

region: NA|EU|… or country

What I would NOT put in attributes (common foot-guns)
Full search queries, emails, names, phone numbers, addresses (PII)

Exact cart contents, SKUs lists, long IDs (cardinality blow-up)

Raw provider error messages (too many unique values)

Instead: bucket, hash, or map to small enums.

Naming + structure I’d follow
Use consistent span ops like: ui.*, api.*, db.*, cache.*, payment.*, checkout.*, order.*

One “umbrella span” per flow (e.g., checkout.start → order.place) so you can see the critical path.

Put decision points as attributes (selected shipping method, payment method) so you can compare cohorts.

If you tell me mobile vs web, and whether checkout is server-rendered vs SPA, I can give you a tighter “top 20 spans” list and suggested attribute keys that match that architecture.

You said:
now lets say you are a Sentry SE, generate a prompt that I can give to Cursor to help me vibe code an e-commerce iOS app with these flows and the custom instrumentation that you suggested
ChatGPT said:
Here’s a Cursor prompt you can paste that will “vibe code” an iOS e-commerce app and wire up the Sentry custom spans/attributes we talked about.

You are an expert iOS engineer and Sentry power user. Build a small but realistic e-commerce iOS app in Swift (SwiftUI + async/await) with clean architecture and FIRST-CLASS observability using Sentry custom spans and attributes.

Goals
- The app should compile and run.
- Implement core e-commerce flows end-to-end with mock network calls and realistic latency/failure simulation.
- Add Sentry instrumentation so we can surface which steps are slow/failing and slice by key attributes.
- Keep attributes low-cardinality and avoid PII.

Tech / Structure
- Swift 5.9+, SwiftUI, async/await, URLSession (mocked), no external dependencies besides Sentry.
- Use a simple architecture: AppState + services (Networking, CatalogService, CartService, CheckoutService, PaymentService, OrderService) + view models.
- Provide a small in-memory backend simulator that returns JSON-like models with configurable delay and error injection.
- Add a single “SentryInstrumentation” utility to standardize span names, ops, and attributes.

Sentry Setup Requirements
- Add Sentry SDK initialization in the app entry point.
- Enable performance tracing (set sample rates in code).
- For every critical flow, create spans/transactions as specified below.
- Use consistent naming + “op” values:
  - ops: ui.*, navigation, api.*, cache, pricing, checkout.*, payment.*, order.*, notification.*
  - spans should be nested properly to reflect the critical path.
- Create helper(s):
  - startTransaction(name, op) returning a transaction/span
  - startChild(parentSpan, name, op) returning span
  - setCommonContext(span): sets common attributes (environment, app version, build, network.type, cache.hit, etc.)
  - recordResult(span, result, failureCategory?) to normalize outcomes

Common Attributes (apply broadly)
- environment: "dev"
- release/build: derive from bundle version
- user.type: guest|logged_in (no user id)
- session.id: UUID per app launch
- region/country (use Locale countryCode only)
- device.class: low|mid|high (derive from device model heuristics; if unsure, stub as "mid")
- network.type: wifi|cellular|offline (stub or use NWPathMonitor; if too much, stub with a toggle)
- cache.hit: true|false where relevant
- payload.size_bucket: 0-10KB|10-100KB|100KB+
- retry.count_bucket: 0|1|2+
- ab.variant: A|B (hardcode toggle in settings)

NEVER send PII
- Do not attach emails, names, full addresses, raw search queries, raw payment error messages.
- Use buckets/enums only (e.g., cart.value_bucket, item_count_bucket).

Flows to Implement + Required Custom Instrumentation
1) App start + navigation
- Span: app.startup with attribute app.startup_type = cold|warm
- Span: navigation / route.change with route.from, route.to (use stable route identifiers)
- When screens load, wrap major work in ui.render.* spans if relevant.

2) Browse + search + product detail
- Transaction/span for search.query
  - child span api.search
  - child span ui.render.results
  - attributes:
    - search.backend: "mock"
    - search.result_count_bucket: 0|1-10|11-50|50+
- Transaction/span for product.detail.load
  - child span api.product.detail
  - optional child span api.recommendations
  - attributes:
    - feature.reco_enabled: true|false

3) Cart
- Spans:
  - cart.load
  - cart.add_item (child api.cart.add, child pricing.recalc)
  - cart.update_quantity
  - cart.remove_item
- Attributes:
  - cart.item_count_bucket: 0|1|2-3|4-10|10+
  - cart.value_bucket: $0-25|25-100|100-250|250+
  - promo.applied: true|false
  - currency: USD|CAD

4) Checkout (address/shipping/taxes)
- Span checkout.start with checkout.type guest|logged_in
- Span checkout.address.submit (child api.address.validate) with validation.result success|fail
- Span checkout.shipping_options.load (child api.shipping.quote)
  - attributes: shipping.destination_country, shipping.method_selected (standard|express|pickup), tax.provider="mock"
- Span checkout.tax.calculate (child api.tax)

5) Payment (most critical)
- Spans:
  - payment.method.select
  - payment.intent.create OR payment.authorize (child api.payment)
  - payment.3ds.challenge (simulate sometimes)
  - payment.capture
  - payment.confirmation.render
- Attributes:
  - payment.provider: "mockpay"
  - payment.method: card|apple_pay|paypal
  - payment.flow: redirect|in_app|3ds
  - payment.result: success|fail|cancel
  - payment.failure_category: validation|network|provider|fraud|insufficient_funds|unknown
  - retry.count_bucket: 0|1|2+

6) Order placement + fulfillment + confirmation
- Span order.place
  - child api.order.create
  - child inventory.reserve
  - child notification.send
- Span order.confirmation.load
- Attributes:
  - order.result success|fail
  - inventory.result reserved|backorder|fail
  - fulfillment.type ship|pickup|digital
  - notification.channels email|sms|push (no addresses)

UX / Screens
- Home (featured + categories)
- Search (search bar + results list)
- Product Detail (add to cart)
- Cart (modify items, apply promo code toggle)
- Checkout (address form stub, shipping selection, tax display)
- Payment (select method; simulate 3DS sometimes; confirm)
- Order Confirmation (order summary)

Backend Simulator
- Provide deterministic toggles in a “Debug Settings” screen:
  - latency profile: fast|normal|slow
  - failure injection by endpoint: search, product detail, cart, shipping quote, tax, payment, order
  - simulate offline
- Backend returns typed models: Product, CartItem, Cart, ShippingOption, TaxQuote, PaymentIntent, Order

Error Handling
- When any step fails, set span status and normalized failure_category.
- Ensure spans end in all code paths (success/failure/cancel).
- Make sure transactions/spans are not left open when user navigates away.

Deliverables
- Create all files needed in a single Xcode project layout.
- Include code snippets for Sentry init and the SentryInstrumentation helper.
- Ensure the app runs with mock data and produces traces with the span names/attributes above.
- Add brief inline comments where instrumentation is applied and why.

Now generate the code.
If you want, tell me whether your target is SwiftUI-only (above), or UIKit + SwiftUI, and whether you want real network + local stub server vs pure in-app simulator, and I’ll tweak the prompt to match.
import SwiftUI

struct CartView: View {
    @EnvironmentObject var appState: AppState
    @State private var isUpdating = false
    
    var body: some View {
        Group {
            if appState.cart.items.isEmpty {
                emptyCartView
            } else {
                cartContentView
            }
        }
        .navigationTitle("Cart")
        .onAppear {
            appState.navigateTo("cart")
        }
    }
    
    private var emptyCartView: some View {
        ContentUnavailableView(
            "Your Cart is Empty",
            systemImage: "cart",
            description: Text("Add some products to get started")
        )
    }
    
    private var cartContentView: some View {
        VStack(spacing: 0) {
            // Cart Items List
            List {
                ForEach(appState.cart.items) { item in
                    CartItemRow(
                        item: item,
                        onQuantityChange: { newQuantity in
                            updateQuantity(itemId: item.id, quantity: newQuantity)
                        },
                        onRemove: {
                            removeItem(itemId: item.id)
                        }
                    )
                }
                
                // Promo Code Toggle
                Section {
                    Toggle("Apply Promo Code (Save $10)", isOn: Binding(
                        get: { appState.cart.promoApplied },
                        set: { _ in appState.cartService.togglePromo() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }
            }
            .listStyle(.plain)
            
            // Cart Summary
            VStack(spacing: 16) {
                Divider()
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(String(format: "$%.2f", appState.cart.subtotal))
                    }
                    
                    if appState.cart.promoApplied {
                        HStack {
                            Text("Promo Discount")
                                .foregroundColor(.green)
                            Spacer()
                            Text(String(format: "-$%.2f", appState.cart.promoDiscount))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text(String(format: "$%.2f", appState.cart.total))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .font(.title3)
                }
                .padding(.horizontal)
                
                // Checkout Button
                NavigationLink(value: "checkout") {
                    HStack {
                        Image(systemName: "creditcard")
                        Text("Proceed to Checkout")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(uiColor: .systemBackground))
        }
        .overlay {
            if isUpdating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    private func updateQuantity(itemId: String, quantity: Int) {
        Task {
            isUpdating = true
            defer { isUpdating = false }
            
            do {
                try await appState.cartService.updateQuantity(itemId: itemId, quantity: quantity)
            } catch {
                appState.errorMessage = "Failed to update quantity"
            }
        }
    }
    
    private func removeItem(itemId: String) {
        Task {
            isUpdating = true
            defer { isUpdating = false }
            
            do {
                try await appState.cartService.removeItem(itemId: itemId)
            } catch {
                appState.errorMessage = "Failed to remove item"
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Product Image
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(item.product.priceFormatted)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                // Quantity Stepper
                HStack {
                    Button(action: {
                        if item.quantity > 1 {
                            onQuantityChange(item.quantity - 1)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(item.quantity > 1 ? .blue : .gray)
                    }
                    .disabled(item.quantity <= 1)
                    
                    Text("\(item.quantity)")
                        .frame(width: 30)
                        .font(.subheadline)
                    
                    Button(action: {
                        onQuantityChange(item.quantity + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text(String(format: "$%.2f", item.total))
                    .font(.headline)
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}


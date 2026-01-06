import SwiftUI

struct OrderConfirmationView: View {
    @EnvironmentObject var appState: AppState
    let order: Order
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Icon
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Order Confirmed!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Thank you for your purchase")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
                
                // Order Details Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Order Details")
                        .font(.headline)
                    
                    Divider()
                    
                    HStack {
                        Text("Order Number")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(order.id.prefix(8).uppercased())
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Date")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(order.createdAt, style: .date)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack {
                            Image(systemName: order.status == "confirmed" ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundColor(order.status == "confirmed" ? .green : .orange)
                            Text(order.status.capitalized)
                                .fontWeight(.medium)
                                .foregroundColor(order.status == "confirmed" ? .green : .orange)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items Ordered")
                        .font(.headline)
                    
                    ForEach(order.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.product.name)
                                    .font(.subheadline)
                                Text("Qty: \(item.quantity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "$%.2f", item.total))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        
                        if item.id != order.items.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Shipping Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shipping Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Method: \(order.shippingMethod.capitalized)")
                            .font(.subheadline)
                        
                        Divider()
                        
                        Text("Shipping Address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        Text(order.shippingAddress.street)
                        Text("\(order.shippingAddress.city), \(order.shippingAddress.state) \(order.shippingAddress.zipCode)")
                        Text(order.shippingAddress.country)
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Payment Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Summary")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Subtotal")
                            Spacer()
                            Text(String(format: "$%.2f", order.subtotal))
                        }
                        
                        HStack {
                            Text("Shipping")
                            Spacer()
                            Text(String(format: "$%.2f", order.shippingCost))
                        }
                        
                        HStack {
                            Text("Tax")
                            Spacer()
                            Text(String(format: "$%.2f", order.tax))
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .fontWeight(.bold)
                            Spacer()
                            Text(String(format: "$%.2f", order.total))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .font(.headline)
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Inventory Status Notice
                if order.status == "backorder" {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Some items are on backorder and will ship when available.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        // Return to home and clear navigation stack
                        appState.navigationPath = NavigationPath()
                        appState.navigateTo("home")
                    }) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Continue Shopping")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Text("A confirmation email has been sent to your email address.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Order Confirmation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            appState.navigateTo("order_confirmation")
        }
    }
}


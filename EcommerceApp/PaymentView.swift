import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isProcessing = false
    @State private var requires3DS = false
    @State private var show3DSChallenge = false
    @State private var paymentComplete = false
    @State private var paymentError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Payment Method Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Method")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            PaymentMethodButton(
                                method: .card,
                                icon: "creditcard.fill",
                                title: "Credit Card",
                                isSelected: appState.selectedPaymentMethod == .card,
                                onSelect: {
                                    appState.paymentService.selectPaymentMethod(.card)
                                }
                            )
                            
                            PaymentMethodButton(
                                method: .applePay,
                                icon: "applelogo",
                                title: "Apple Pay",
                                isSelected: appState.selectedPaymentMethod == .applePay,
                                onSelect: {
                                    appState.paymentService.selectPaymentMethod(.applePay)
                                }
                            )
                            
                            PaymentMethodButton(
                                method: .paypal,
                                icon: "dollarsign.circle.fill",
                                title: "PayPal",
                                isSelected: appState.selectedPaymentMethod == .paypal,
                                onSelect: {
                                    appState.paymentService.selectPaymentMethod(.paypal)
                                }
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Order Total
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Total")
                            .font(.headline)
                        
                        let total = calculateTotal()
                        Text(String(format: "$%.2f", total))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Retry count indicator (if retrying)
                    if appState.paymentRetryCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Payment attempt \(appState.paymentRetryCount + 1)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Error Message
                    if let error = paymentError {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Payment Button
            VStack(spacing: 12) {
                Button(action: processPayment) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "lock.fill")
                            Text("Pay Now")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                
                Text("Your payment is secure and encrypted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .alert("3D Secure Verification", isPresented: $show3DSChallenge) {
            Button("Verify", role: .none) {
                handle3DS()
            }
            Button("Cancel", role: .cancel) {
                paymentError = "Payment cancelled"
                isProcessing = false
            }
        } message: {
            Text("Your bank requires additional verification to complete this purchase.")
        }
        .navigationDestination(isPresented: $paymentComplete) {
            if let order = appState.currentOrder {
                OrderConfirmationView(order: order)
            }
        }
        .onAppear {
            appState.navigateTo("payment")
        }
    }
    
    private func calculateTotal() -> Double {
        let shipping = appState.selectedShippingOption?.price ?? 0
        let tax = appState.taxQuote?.amount ?? 0
        return appState.cart.total + shipping + tax
    }
    
    private func processPayment() {
        Task {
            isProcessing = true
            paymentError = nil
            
            do {
                let total = calculateTotal()
                
                // STEP 1: Authorize payment
                let intent = try await appState.paymentService.authorizePayment(amount: total)
                
                // STEP 2: Check if 3DS required
                if intent.requiresAction {
                    requires3DS = true
                    show3DSChallenge = true
                    return // Wait for user to handle 3DS
                }
                
                // STEP 3: Capture payment
                try await appState.paymentService.capturePayment()
                
                // STEP 4: Place order
                let order = try await appState.orderService.placeOrder()
                
                // STEP 5: Load confirmation
                try await appState.orderService.loadOrderConfirmation(orderId: order.id)
                
                // Navigate to confirmation
                isProcessing = false
                paymentComplete = true
                
            } catch let error as ServiceError {
                isProcessing = false
                paymentError = error.localizedDescription
            } catch {
                isProcessing = false
                paymentError = "An unexpected error occurred"
            }
        }
    }
    
    private func handle3DS() {
        Task {
            do {
                guard let paymentIntent = appState.paymentIntent else {
                    throw ServiceError.validationError
                }
                
                // Handle 3DS challenge
                try await appState.paymentService.handle3DSChallenge(paymentIntentId: paymentIntent.id)
                
                // Continue with payment capture
                try await appState.paymentService.capturePayment()
                
                // Place order
                let order = try await appState.orderService.placeOrder()
                
                // Load confirmation
                try await appState.orderService.loadOrderConfirmation(orderId: order.id)
                
                // Navigate to confirmation
                isProcessing = false
                paymentComplete = true
                
            } catch let error as ServiceError {
                isProcessing = false
                paymentError = error.localizedDescription
            } catch {
                isProcessing = false
                paymentError = "3DS verification failed"
            }
        }
    }
}

struct PaymentMethodButton: View {
    let method: PaymentMethod
    let icon: String
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}


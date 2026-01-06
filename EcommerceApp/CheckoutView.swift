import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject var appState: AppState
    @State private var shippingOptions: [ShippingOption] = []
    @State private var isLoading = false
    @State private var currentStep: CheckoutStep = .address
    
    enum CheckoutStep {
        case address
        case shipping
        case review
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            HStack(spacing: 0) {
                StepIndicator(step: 1, title: "Address", isActive: currentStep == .address, isCompleted: currentStep.rawValue > CheckoutStep.address.rawValue)
                StepIndicator(step: 2, title: "Shipping", isActive: currentStep == .shipping, isCompleted: currentStep.rawValue > CheckoutStep.shipping.rawValue)
                StepIndicator(step: 3, title: "Review", isActive: currentStep == .review, isCompleted: false)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            Divider()
            
            // Step Content
            ScrollView {
                VStack(spacing: 20) {
                    switch currentStep {
                    case .address:
                        addressStepView
                    case .shipping:
                        shippingStepView
                    case .review:
                        reviewStepView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            appState.navigateTo("checkout")
            appState.checkoutService.startCheckout()
        }
    }
    
    // MARK: - Address Step
    
    private var addressStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shipping Address")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                TextField("Street Address", text: $appState.shippingAddress.street)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("City", text: $appState.shippingAddress.city)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    TextField("State", text: $appState.shippingAddress.state)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("ZIP", text: $appState.shippingAddress.zipCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                TextField("Country", text: $appState.shippingAddress.country)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button(action: submitAddress) {
                HStack {
                    Text("Continue to Shipping")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(appState.shippingAddress.isValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!appState.shippingAddress.isValid || isLoading)
        }
    }
    
    private func submitAddress() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await appState.checkoutService.submitAddress(appState.shippingAddress)
                
                // Load shipping options
                let options = try await appState.checkoutService.loadShippingOptions()
                shippingOptions = options
                
                withAnimation {
                    currentStep = .shipping
                }
            } catch {
                appState.errorMessage = "Address validation failed"
            }
        }
    }
    
    // MARK: - Shipping Step
    
    private var shippingStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shipping Method")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(shippingOptions) { option in
                    ShippingOptionCard(
                        option: option,
                        isSelected: appState.selectedShippingOption?.id == option.id,
                        onSelect: {
                            appState.checkoutService.selectShippingMethod(option)
                        }
                    )
                }
            }
            
            HStack {
                Button(action: {
                    withAnimation {
                        currentStep = .address
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: calculateTax) {
                    HStack {
                        Text("Continue to Review")
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(appState.selectedShippingOption != nil ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(appState.selectedShippingOption == nil || isLoading)
            }
        }
    }
    
    private func calculateTax() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await appState.checkoutService.calculateTax()
                withAnimation {
                    currentStep = .review
                }
            } catch {
                appState.errorMessage = "Failed to calculate tax"
            }
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review Order")
                .font(.title2)
                .fontWeight(.bold)
            
            // Order Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Order Summary")
                    .font(.headline)
                
                ForEach(appState.cart.items.prefix(3)) { item in
                    HStack {
                        Text("\(item.quantity)x \(item.product.name)")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "$%.2f", item.total))
                            .font(.subheadline)
                    }
                }
                
                if appState.cart.items.count > 3 {
                    Text("+ \(appState.cart.items.count - 3) more items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Shipping Address
            VStack(alignment: .leading, spacing: 8) {
                Text("Shipping Address")
                    .font(.headline)
                
                Text(appState.shippingAddress.street)
                Text("\(appState.shippingAddress.city), \(appState.shippingAddress.state) \(appState.shippingAddress.zipCode)")
                Text(appState.shippingAddress.country)
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Cost Breakdown
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
                
                if let shipping = appState.selectedShippingOption {
                    HStack {
                        Text("Shipping (\(shipping.name))")
                        Spacer()
                        Text(String(format: "$%.2f", shipping.price))
                    }
                }
                
                if let tax = appState.taxQuote {
                    HStack {
                        Text("Tax")
                        Spacer()
                        Text(String(format: "$%.2f", tax.amount))
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text(String(format: "$%.2f", calculateTotal()))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .font(.title3)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Navigation Buttons
            HStack {
                Button(action: {
                    withAnimation {
                        currentStep = .shipping
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                NavigationLink(value: "payment") {
                    HStack {
                        Text("Continue to Payment")
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func calculateTotal() -> Double {
        let shipping = appState.selectedShippingOption?.price ?? 0
        let tax = appState.taxQuote?.amount ?? 0
        return appState.cart.total + shipping + tax
    }
}

// MARK: - Supporting Views

extension CheckoutView.CheckoutStep: Comparable {
    var rawValue: Int {
        switch self {
        case .address: return 0
        case .shipping: return 1
        case .review: return 2
        }
    }
    
    static func < (lhs: CheckoutView.CheckoutStep, rhs: CheckoutView.CheckoutStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct StepIndicator: View {
    let step: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(isActive ? Color.blue : isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 30)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption)
                } else {
                    Text("\(step)")
                        .foregroundColor(isActive ? .white : .gray)
                        .font(.caption)
                }
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(isActive ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShippingOptionCard: View {
    let option: ShippingOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(option.estimatedDays) business days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "$%.2f", option.price))
                    .font(.headline)
                    .foregroundColor(.blue)
                
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


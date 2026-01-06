import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject var appState: AppState
    let product: Product
    
    @State private var recommendations: [Product] = []
    @State private var isLoading = false
    @State private var isAddingToCart = false
    @State private var showAddedToCart = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Product Image
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Product Info
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(product.priceFormatted)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        if product.inStock {
                            Label("In Stock", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        } else {
                            Label("Out of Stock", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                    
                    Text(product.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Divider()
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                    
                    Text(product.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Add to Cart Button
                    Button(action: addToCart) {
                        HStack {
                            if isAddingToCart {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "cart.badge.plus")
                                Text("Add to Cart")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(product.inStock ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!product.inStock || isAddingToCart)
                    
                    // Recommendations
                    if !recommendations.isEmpty {
                        Divider()
                            .padding(.vertical)
                        
                        Text("You might also like")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recommendations) { recommended in
                                    NavigationLink(value: recommended) {
                                        RecommendationCard(product: recommended)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Product Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Added to Cart", isPresented: $showAddedToCart) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(product.name) has been added to your cart")
        }
        .task {
            await loadProductDetails()
        }
        .onAppear {
            appState.navigateTo("product_detail")
        }
    }
    
    private func loadProductDetails() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (_, reco) = try await appState.catalogService.getProductDetail(
                id: product.id,
                includeRecommendations: true
            )
            recommendations = reco
        } catch {
            print("Error loading product details: \(error)")
        }
    }
    
    private func addToCart() {
        Task {
            isAddingToCart = true
            defer { isAddingToCart = false }
            
            do {
                try await appState.cartService.addItem(product: product)
                showAddedToCart = true
            } catch {
                appState.errorMessage = "Failed to add item to cart"
            }
        }
    }
}

struct RecommendationCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(product.priceFormatted)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}


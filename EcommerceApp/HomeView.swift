import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var featuredProducts: [Product] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to EcommerceApp")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Discover amazing products")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Featured Products
                VStack(alignment: .leading, spacing: 12) {
                    Text("Featured Products")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(featuredProducts) { product in
                                    NavigationLink(value: product) {
                                        ProductCard(product: product)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Categories
                VStack(alignment: .leading, spacing: 12) {
                    Text("Categories")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        CategoryCard(name: "Electronics", icon: "laptopcomputer")
                        CategoryCard(name: "Accessories", icon: "headphones")
                        CategoryCard(name: "Wearables", icon: "applewatch")
                        CategoryCard(name: "Audio", icon: "hifispeaker.fill")
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .task {
            await loadFeaturedProducts()
        }
        .onAppear {
            appState.navigateTo("home")
        }
    }
    
    private func loadFeaturedProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Search for all products and take first 6 as featured
            let results = try await appState.catalogService.search(query: "")
            featuredProducts = Array(results.prefix(6))
        } catch {
            print("Error loading featured products: \(error)")
        }
    }
}

struct ProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 160, height: 160)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(product.priceFormatted)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .frame(width: 160, alignment: .leading)
        }
    }
}

struct CategoryCard: View {
    let name: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}


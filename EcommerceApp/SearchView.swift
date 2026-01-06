import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchQuery = ""
    @State private var searchResults: [Product] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Results
            if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try searching for something else")
                )
            } else if searchResults.isEmpty && searchQuery.isEmpty {
                ContentUnavailableView(
                    "Search Products",
                    systemImage: "magnifyingglass",
                    description: Text("Enter a search term to find products")
                )
            } else {
                List {
                    ForEach(searchResults) { product in
                        NavigationLink(value: product) {
                            SearchResultRow(product: product)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchQuery, prompt: "Search for products")
        .onSubmit(of: .search) {
            Task {
                await performSearch()
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            // Debounced search would go here
            // For simplicity, we'll just search on submit
            if newValue.isEmpty {
                searchResults = []
            }
        }
        .overlay {
            if isSearching {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            appState.navigateTo("search")
        }
    }
    
    private func performSearch() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let results = try await appState.catalogService.search(query: searchQuery)
            searchResults = results
        } catch {
            print("Search error: \(error)")
            appState.errorMessage = error.localizedDescription
        }
    }
}

struct SearchResultRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 16) {
            // Product image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                
                Text(product.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(product.priceFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            if product.inStock {
                Text("In Stock")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Out of Stock")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}


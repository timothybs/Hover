//
//  ProductsView.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//

import SwiftUI

struct ProductsView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productCache: ProductCache

    @State private var searchText = ""
    @State private var showingScanner = false

    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]
    

    var body: some View {
        NavigationView {
            VStack {
                let isLoading = productCache.productsByBarcode.isEmpty
                let filteredProducts = productCache.productsByBarcode.values
                    .filter {
                        searchText.isEmpty ||
                        $0.name.lowercased().contains(searchText.lowercased()) ||
                        $0.id.contains(searchText)
                    }
                    .sorted { $0.name < $1.name }
                HStack {
                    TextField("Search for a product", text: $searchText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    Button(action: {
                        showingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .imageScale(.large)
                            .padding(.leading, 4)
                    }
                }
                .padding()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredProducts, id: \.id) { product in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.name)
                                        .font(.headline)
                                    Text(String(format: "£%.2f", product.price))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerScreen()
            }
        }
    }
}

#Preview {
    ProductsView()
        .environmentObject(CartManager())
        .environmentObject(ProductCache())
}

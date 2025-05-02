//
//  ProductsView.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//

import SwiftUI

struct ProductsView: View {
    @EnvironmentObject var cartManager: CartManager

    let mockProducts = [
        Product(id: "tshirt", name: "T-Shirt", price: 19.99),
        Product(id: "hoodie", name: "Hoodie", price: 39.99),
        Product(id: "sneakers", name: "Sneakers", price: 89.99)
    ]

    var body: some View {
        NavigationView {
            List(mockProducts) { product in
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                        Text(String(format: "$%.2f", product.price))
                            .font(.subheadline)
                    }
                    Spacer()
                    Button("Add to Cart") {
                        print("Tapped add for \(product.name)")
                            cartManager.addToCart(product)
                            print("Cart now has: \(cartManager.items)")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("🛍️ Products")
        }
    }
}

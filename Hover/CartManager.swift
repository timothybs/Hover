//
//  CartManager.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import Foundation
import SwiftUI

class CartManager: ObservableObject {
    init() {
        print("🛒 CartManager initialized")
    }
    @Published var items: [Product: Int] = [:]
    @Published var paymentInProgress = false

    func addToCart(_ product: Product) {
        items[product, default: 0] += 1
        print("Added \(product.name) to cart. Quantity: \(items[product]!)")

    }
    
    func add(product: Product) {
        items[product, default: 0] += 1
    }

    func removeFromCart(_ product: Product) {
        items[product] = nil
    }

    func updateQuantity(for product: Product, quantity: Int) {
        if quantity <= 0 {
            removeFromCart(product)
        } else {
            items[product] = quantity
        }
    }

    func totalPrice() -> Double {
        items.reduce(0) { $0 + ($1.key.price * Double($1.value)) }
    }
    
    func clearCart() {
        items.removeAll()
        paymentInProgress = false
    }
}

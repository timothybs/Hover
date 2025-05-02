//
//  MainView.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import SwiftUI

struct MainView: View {
    @StateObject var cartManager = CartManager()

    var body: some View {
        TabView {
            ProductsView()
                .tabItem {
                    Label("Products", systemImage: "bag")
                }
            CartView()
                .tabItem {
                    Label("Cart", systemImage: "cart")
                }
            CheckoutView()
                .tabItem {
                    Label("Checkout", systemImage: "creditcard")
                }
        }
        .environmentObject(cartManager)
    }
}

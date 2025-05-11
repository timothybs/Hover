//
//  MainView.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import SwiftUI

struct MainView: View {
    @StateObject var cartManager = CartManager()
    @State private var selectedTab = 0
    @State private var showingMenu = false

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $selectedTab) {
                    ProductsView()
                        .tabItem {
                            Label("Products", systemImage: "bag")
                        }
                        .tag(0)

                    OrdersView()
                        .tabItem {
                            Label("Orders", systemImage: "list.bullet")
                        }
                        .tag(1)

                    CartView()
                        .tabItem {
                            Label("Cart", systemImage: "cart")
                        }
                        .tag(2)

                    CheckoutView()
                        .tabItem {
                            Label("Checkout", systemImage: "creditcard")
                        }
                        .tag(3)
                }
                .environmentObject(cartManager)
                .frame(minHeight: 0, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingMenu.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .navigationDestination(isPresented: $showingMenu) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ProductsView()
        .environmentObject(CartManager())
        .environmentObject(ProductCache())
}

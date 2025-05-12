//
//  HoverAppRootView.swift
//  Hover
//
//  Created by Timothy Sumner on 12/05/2025.
//


import SwiftUI

struct HoverAppRootView: View {
    @StateObject var auth = AuthManager()
    @StateObject private var cartManager = CartManager()
    @StateObject private var productCache = ProductCache()
    @AppStorage("colorSchemeOption") private var selectedColorScheme: ColorSchemeOption = .system
    @State private var isReady = false

    var body: some View {
        Group {
            if !auth.isLoggedIn {
                LoginView()
            } else if let _ = auth.merchant, isReady {
                MainView()
                    .environmentObject(cartManager)
                    .environmentObject(productCache)
            } else {
                ProgressView("Loading...")
            }
        }
        .environmentObject(auth)
        .preferredColorScheme({
            switch selectedColorScheme {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }())
        .task(id: auth.isLoggedIn ? "startup" : "no-startup") {
            if auth.isLoggedIn {
                await performStartup()
                isReady = true
            }
        }
    }

    private func performStartup() async {
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        await app.performStartup(auth: auth, productCache: productCache)
    }
}

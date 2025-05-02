import SwiftUI
import StripeTerminal

@main
struct HoverApp: App {
    @UIApplicationDelegateAdaptor(StripeSetupDelegate.self) var stripeDelegate
    @StateObject private var cartManager = CartManager()
    @StateObject private var productCache = ProductCache()
    
    var body: some Scene {
        WindowGroup {
            TabView {
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
            .environmentObject(productCache)
            .task {
                print("🟡 Starting setup in HoverApp")
                // --- Stripe and App Diagnostics Begin ---
                if let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String] {
                    print("📦 UIBackgroundModes at runtime: \(modes)")
                } else {
                    print("⚠️ UIBackgroundModes key is missing at runtime.")
                }

                print("🖥 App bundle identifier: \(Bundle.main.bundleIdentifier ?? "nil")")
                print("📁 Info.plist keys:")
                for (key, value) in Bundle.main.infoDictionary ?? [:] {
                    print(" - \(key): \(value)")
                }

                if let locationUsage = Bundle.main.infoDictionary?["NSLocationWhenInUseUsageDescription"] {
                    print("📍 NSLocationWhenInUseUsageDescription at runtime: \(locationUsage)")
                } else {
                    print("⚠️ NSLocationWhenInUseUsageDescription is MISSING at runtime")
                }
                // --- Stripe and App Diagnostics End ---
                print("✅ Stripe Terminal token provider has been set")
                do {
                    let config = try BluetoothScanDiscoveryConfigurationBuilder().setSimulated(true).build()
                    Terminal.shared.discoverReaders(config, delegate: DummyDiscoveryDelegate()) { error in
                        if let error = error {
                            print("❌ Discovery error: \(error)")
                        } else {
                            print("✅ Reader discovery started from HoverApp")
                        }
                    }
                } catch {
                    print("❌ Failed to start discovery: \(error)")
                }
                await productCache.loadAllProducts()
                print("✅ Finished loading \(productCache.productsByBarcode.count) products")
            }
        }
    }
}

class DummyDiscoveryDelegate: NSObject, DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        print("📡 DummyDiscoveryDelegate saw readers: \(readers.map { $0.serialNumber })")
    }
}

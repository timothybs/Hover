import ProximityReader
import SwiftUI
import StripeTerminal

@main
struct HoverApp: App {
    var discoveryDelegate: DummyDiscoveryDelegate

    init() {
        let delegate = DummyDiscoveryDelegate()
        self.discoveryDelegate = delegate
    }
    
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
                    let config = try TapToPayDiscoveryConfigurationBuilder().build()
                    Terminal.shared.discoverReaders(config, delegate: discoveryDelegate) { error in
                        if let error = error {
                            print("❌ Discovery error: \(error)")
                        } else {
                            print("✅ Reader discovery started from HoverApp")
                        }
                    }
                } catch {
                    print("❌ Failed to start Tap to Pay discovery: \(error)")
                }
                await productCache.loadAllProducts()
                print("✅ Finished loading \(productCache.productsByBarcode.count) products")
            }
        }
    }
}

class DummyDiscoveryDelegate: NSObject, DiscoveryDelegate, TapToPayReaderDelegate {
    override init() {
        super.init()
        print("📡 DummyDiscoveryDelegate initialized")
    }
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        for reader in readers {
            print("📡 Discovered reader: \(reader.label ?? "Unnamed") — deviceType rawValue: \(reader.deviceType.rawValue)")
        }
        // 11 = stripe_iOS_TTP (Tap to Pay on iPhone)
        let tapToPayReaders = readers.filter { $0.deviceType.rawValue == 11 }
        if tapToPayReaders.isEmpty {
            print("⚠️ No Tap to Pay (iOS_TTP) readers found.")
            return
        }
        
        for reader in tapToPayReaders {
            print("📡 Tap to Pay reader: \(reader.label ?? "Unnamed") — deviceType: \(reader.deviceType.rawValue)")
        }
        
        // Optionally auto-connect to the first real Tap to Pay reader:
        if let selectedReader = tapToPayReaders.first {
            let connectionConfig = try! TapToPayConnectionConfigurationBuilder(
                delegate: self,
                locationId: "tml_GBHd6w8AIWbPOL"
            ).build()

            Terminal.shared.connectReader(selectedReader, connectionConfig: connectionConfig) { reader, error in
                if let error = error {
                    print("❌ Failed to connect to Tap to Pay reader: \(error)")
                } else if let connectedReader = reader {
                    print("✅ Connected to Tap to Pay reader: \(connectedReader.label ?? "Unnamed")")

                    Task {
                        do {
                            var request = URLRequest(url: URL(string: "https://v0-pos-mvp.vercel.app/api/create-payment-intent")!)
                            request.httpMethod = "POST"
                            let (data, _) = try await URLSession.shared.data(for: request)
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            guard let clientSecret = json?["client_secret"] as? String else {
                                print("❌ Invalid response from /create-payment-intent")
                                return
                            }

                            let paymentIntent = try await Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret)

                            Terminal.shared.collectPaymentMethod(paymentIntent) { collectedIntent, error in
                                if let error = error {
                                    print("❌ Failed to collect payment method: \(error)")
                                } else if let collectedIntent = collectedIntent {
                                    print("✅ Collected payment method for intent: \(collectedIntent.stripeId ?? "unknown")")
                                    // Optionally: send to backend for confirmation
                                } else {
                                    print("⚠️ No error, but no collected intent returned.")
                                }
                            }
                        } catch {
                            print("❌ Error fetching PaymentIntent: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {
        print("🔄 Reader update available: \(update)")
    }

    func tapToPayReader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        print("⬇️ Installing update: \(update)")
    }

    func tapToPayReader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        print("📶 Update progress: \(Int(progress * 100))%")
    }

    func tapToPayReader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {
        if let error = error {
            print("❌ Update failed: \(error)")
        } else {
            print("✅ Update installed successfully")
        }
    }

    func reader(_ reader: Reader, didReportReaderEvent event: ReaderEvent) {
        print("📣 Reader event: \(event)")
    }

    func tapToPayReader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions) {
        print("🔧 Reader input requested: \(inputOptions)")
    }

    func tapToPayReader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {
        print("💬 Reader display message: \(displayMessage)")
    }
    

    func reader(_ reader: Reader, didChangeLocation location: Location) {
        print("📍 Reader changed location to: \(location.displayName ?? "Unnamed location")")
    }
    
    func reader(_ reader: Reader, didChangePaymentStatus status: PaymentStatus) {
        print("💳 Tap to Pay payment status changed: \(status)")
    }

    func reader(_ reader: Reader, didChangeBatteryLevel batteryLevel: Float) {
        print("🔋 Reader battery level changed: \(batteryLevel * 100)%")
    }
}

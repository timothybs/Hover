import ProximityReader
import SwiftUI
import StripeTerminal

let isLive = true

var stripeLocationId: String {
    isLive ? "tml_GBHd6w8AIWbPOL" : "tml_GA6b6wmVQloBTz"
}

var apiBaseURL: String {
    isLive ? "https://v0-pos-mvp.vercel.app" : "http://192.168.1.204:3000"
}

@main
struct HoverApp: App {
    var discoveryDelegate: DummyDiscoveryDelegate
    @State private var isReady = false

    init() {
        let delegate = DummyDiscoveryDelegate()
        self.discoveryDelegate = delegate
    }
    
    @UIApplicationDelegateAdaptor(StripeSetupDelegate.self) var stripeDelegate
    @StateObject private var cartManager = CartManager()
    @StateObject private var productCache = ProductCache()
        
    var body: some Scene {
        WindowGroup {
            Group {
                if isReady {
                    MainView()
                        .environmentObject(cartManager)
                        .environmentObject(productCache)
                } else {
                    ProgressView("Loading...")
                }
            }
            .task(id: "startup") {
                await performStartup()
            }
        }
    }
    
    private func performStartup() async {
        print("🛠 performStartup() task has started")
        print("🟡 Starting setup in HoverApp")
        print("🧪 isLive: \(isLive)")
        print("🧪 stripeLocationId: \(stripeLocationId)")
        print("🧪 apiBaseURL: \(apiBaseURL)")
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
        print("🟣 Calling loadAllProducts() on ProductCache")
        await productCache.loadAllProducts()
        print("✅ Finished loading \(productCache.productsByBarcode.count) products")
        isReady = true
    }
}

class DummyDiscoveryDelegate: NSObject, DiscoveryDelegate, TapToPayReaderDelegate, InternetReaderDelegate {
    override init() {
        super.init()
        print("📡 DummyDiscoveryDelegate initialized")
    }
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        for reader in readers {
            print("📡 Discovered reader: \(reader.label ?? "Unnamed") — deviceType rawValue: \(reader.deviceType.rawValue)")
        }
        // 11 = stripe_iOS_TTP (Tap to Pay on iPhone)
        let eligibleReaders = readers.filter { isLive ? $0.deviceType.rawValue == 11 : true }

        if eligibleReaders.isEmpty {
            print("⚠️ No eligible readers found.")
            return
        }

        for reader in eligibleReaders {
            print("📡 Eligible reader: \(reader.label ?? "Unnamed") — deviceType: \(reader.deviceType.rawValue)")
        }

        if let selectedReader = eligibleReaders.first {
            let connectionConfig: ConnectionConfiguration
            if selectedReader.deviceType.rawValue == 11 {
                // Tap to Pay on iPhone
                connectionConfig = try! TapToPayConnectionConfigurationBuilder(
                    delegate: self,
                    locationId: stripeLocationId
                ).build()
            } else {
                // Simulated reader fallback
                connectionConfig = try! InternetConnectionConfigurationBuilder(
                    delegate: self,
                ).build()
            }

            Terminal.shared.connectReader(selectedReader, connectionConfig: connectionConfig) { reader, error in
                if let error = error {
                    print("❌ Failed to connect to Tap to Pay reader: \(error)")
                } else if let connectedReader = reader {
                    print("✅ Connected to Tap to Pay reader: \(connectedReader.label ?? "Unnamed")")
                    // You can trigger UI updates or reset app state here if needed.
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

        // Improved cancellation detection for Tap to Pay
        let lower = "\(event)".lowercased()
        let cancelTriggers = ["cancel", "timeout", "not_ready", "no_card"]

        if cancelTriggers.contains(where: { lower.contains($0) }) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .paymentDidFailOrCancel, object: nil)
            }
        }
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
        if status == PaymentStatus.notReady || status == PaymentStatus.ready {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .paymentDidFailOrCancel, object: nil)
            }
        }
    }

    func reader(_ reader: Reader, didChangeBatteryLevel batteryLevel: Float) {
        print("🔋 Reader battery level changed: \(batteryLevel * 100)%")
    }
}

extension Notification.Name {
    static let paymentDidFailOrCancel = Notification.Name("paymentDidFailOrCancel")
}

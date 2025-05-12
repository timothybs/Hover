import UIKit
import StripeTerminal

let isLive = true

var apiBaseURL: String {
    isLive ? "https://v0-pos-mvp.vercel.app" : "http://192.168.1.204:3000"
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var discoveryDelegate: DummyDiscoveryDelegate?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func performStartup(auth: AuthManager, productCache: ProductCache) async {
        print("🛠 performStartup() task has started")
        print("🔐 isLoggedIn =", auth.isLoggedIn)
        print("🔐 accessToken =", auth.accessToken ?? "nil")

        guard auth.isLoggedIn, let token = auth.accessToken else {
            print("⚠️ No logged-in user or token available. Skipping merchant fetch and catalog load.")
            return
        }

        guard let url = URL(string: "\(apiBaseURL)/api/merchant") else {
            print("❌ Invalid merchant API URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            print("📦 Raw merchant response: \(String(data: data, encoding: .utf8) ?? "nil")")

            let merchant = try JSONDecoder().decode(Merchant.self, from: data)
            print("✅ Merchant loaded: \(merchant)")

            print("🟣 Calling loadAllProducts() on ProductCache")
            await productCache.loadAllProducts()

            DispatchQueue.main.async {
                auth.merchant = merchant
                Terminal.setTokenProvider(StripeConnectionTokenProvider(auth: auth))

                let delegate = DummyDiscoveryDelegate(auth: auth)
                self.discoveryDelegate = delegate

                do {
                    let configBuilder = TapToPayDiscoveryConfigurationBuilder()
                    let config = try configBuilder.build()
                    Terminal.shared.discoverReaders(config, delegate: delegate) { error in
                        if let error = error {
                            print("❌ Discovery error: \(error)")
                        } else {
                            print("✅ Reader discovery started from AppDelegate")
                        }
                    }
                } catch {
                    print("❌ Failed to start Tap to Pay discovery: \(error)")
                }
            }
        } catch {
            print("❌ Failed to fetch merchant or load products: \(error)")
        }
    }
}
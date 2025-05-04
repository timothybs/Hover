import SwiftUI
import StripeTerminal

class StripeSetupDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🔍 AppDelegate didFinishLaunching START")

        Terminal.setTokenProvider(APIClient.shared)
        print("✅ Stripe Terminal token provider has been set")
        print("Stripe Terminal SDK is active: \(Terminal.shared)")

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

        print("✅ AppDelegate completed setup — about to return true")
        return true
    }
}

class APIClient: ConnectionTokenProvider {
    static let shared = APIClient()

    func fetchConnectionToken(_ completion: @escaping (String?, Error?) -> Void) {
        let url = URL(string: "https://v0-pos-mvp.vercel.app/api/connection_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        print("🔄 Fetching connection token from backend...")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ Token fetch failed: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let secret = json["secret"] as? String else {
                let parseError = NSError(domain: "APIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from token endpoint"])
                print("❌ Token fetch failed: could not parse response")
                completion(nil, parseError)
                return
            }

            print("✅ Received connection token")
            completion(secret, nil)
            print("🚀 Connection token fetch initiated")
            print("📡 Terminal connection status: \(Terminal.shared.connectionStatus.rawValue)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🧪 Stripe Terminal status 1s later: \(Terminal.shared.connectionStatus.rawValue)")
            }
        }.resume()
    }
}

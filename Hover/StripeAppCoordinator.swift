import SwiftUI
import StripeTerminal

class StripeSetupDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🔍 AppDelegate didFinishLaunching START")

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

import SwiftUI

enum SettingsRoute: Hashable {
    case profile
}

enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct SettingsView: View {
    @State private var path = NavigationPath()
    @Environment(\.dismiss) var dismiss
    @AppStorage("colorSchemeOption") private var selectedColorScheme: ColorSchemeOption = .system
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section(header: Text("Account")) {
                    NavigationLink(value: SettingsRoute.profile) {
                        Text("Profile")
                    }
                }

                Section(header: Text("Appearance")) {
                    Picker("Dark / Light / System", selection: $selectedColorScheme) {
                        ForEach(ColorSchemeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section {
                    Button("Sign Out") {
                        UserDefaults.standard.set(false, forKey: "isLoggedIn")
                        auth.isLoggedIn = false
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .profile:
                    Text("Profile screen")
                }
            }
        }
        .preferredColorScheme({
            switch selectedColorScheme {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }())
    }
}

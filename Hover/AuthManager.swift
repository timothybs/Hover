//
//  AuthManager.swift
//  Hover
//
//  Created by Timothy Sumner on 06/05/2025.
//


import Security
import Supabase
import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var session: Session?
    @Published var merchant: Merchant?

    private let client: SupabaseClient = {
        guard
            let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: supabaseURLString)
        else {
            fatalError("❌ Missing Supabase config in Info.plist")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
    }()

    func signIn(email: String, password: String) async {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            let accessToken = session.accessToken
            KeychainHelper.shared.save(key: "email", value: email)
            KeychainHelper.shared.save(key: "password", value: password)
            print("🔐 Access token: \(accessToken)")
            DispatchQueue.main.async { [weak self] in
                self?.session = session
                self?.isLoggedIn = true
                self?.fetchMerchant()
                self?.registerUserIfNeeded()
            }
        } catch {
            print("❌ Login failed:", error.localizedDescription)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        DispatchQueue.main.async { [weak self] in
            self?.session = nil
            self?.isLoggedIn = false
        }
    }
    
    var accessToken: String? {
        return session?.accessToken
    }
    
    func registerUserIfNeeded() {
        guard
            let userId = session?.user.id,
            let merchantId = merchant?.id,
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: "\(supabaseURL)/rest/v1/users")
        else {
            print("❌ Missing user or merchant info for registration")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")

        let payload: [String: Any] = [
            "id": userId,
            "merchant_id": merchantId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: [payload])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Failed to register user in Supabase users table: \(error.localizedDescription)")
            } else if let response = response as? HTTPURLResponse {
                print("📡 registerUserIfNeeded status: \(response.statusCode)")
            }
        }.resume()
    }
    
    /// Fetches the merchant for the current session user and updates `merchant` on the main thread.
    func fetchMerchant() {
        guard
            let userId = session?.user.id,
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: "\(supabaseURL)/rest/v1/merchants?user_id=eq.\(userId)&select=*")
        else {
            print("❌ Missing info for fetching merchant")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Failed to fetch merchant: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("❌ No data returned from merchant fetch")
                return
            }
            do {
                // The Supabase REST API returns an array of merchants
                let merchants = try JSONDecoder().decode([Merchant].self, from: data)
                if let merchant = merchants.first {
                    DispatchQueue.main.async {
                        self?.merchant = merchant
                    }
                } else {
                    print("❌ No merchant found for user")
                }
            } catch {
                print("❌ Error decoding merchant: \(error.localizedDescription)")
            }
        }.resume()
    }
}

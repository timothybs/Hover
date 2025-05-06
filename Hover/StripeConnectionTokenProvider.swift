//
//  StripeConnectionTokenProvider.swift
//  Hover
//
//  Created by Timothy Sumner on 06/05/2025.
//


import Foundation
import StripeTerminal

class StripeConnectionTokenProvider: ConnectionTokenProvider {
    let auth: AuthManager

    init(auth: AuthManager) {
        self.auth = auth
    }

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        guard let token = auth.accessToken else {
            print("❌ No access token available for connection token fetch")
            completion(nil, NSError(domain: "StripeTerminalDemo", code: 401, userInfo: [NSLocalizedDescriptionKey: "No access token"]))
            return
        }

        print("🔐 fetchConnectionToken called — token: \(token)")

        guard let url = URL(string: "https://v0-pos-mvp.vercel.app/api/connection_token") else {
            completion(nil, NSError(domain: "StripeTerminalDemo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        print("📡 Using connection token URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("🔄 Fetching connection token from backend...")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ Token fetch failed: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📥 Raw token response body:", body)
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let secret = json["secret"] as? String else {
                print("❌ Token fetch failed: could not parse response")
                completion(nil, NSError(domain: "StripeTerminalDemo", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"]))
                return
            }

            print("✅ Fetched connection token")
            completion(secret, nil)
        }.resume()
    }
}

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

    private var client = SupabaseClient(
        supabaseURL: URL(string: "https://sswfohwqbyoeugfsxvkd.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzd2ZvaHdxYnlvZXVnZnN4dmtkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM0OTU5MzIsImV4cCI6MjA1OTA3MTkzMn0.hlp4QdeGwvu2saYutHwSZG3Em_b8W9gZwltfZbuxlY8"
    )

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
}

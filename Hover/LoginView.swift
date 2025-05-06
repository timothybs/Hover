//
//  LoginView.swift
//  Hover
//
//  Created by Timothy Sumner on 06/05/2025.
//
import SwiftUI
import Security

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email = KeychainHelper.shared.read(key: "email") ?? ""
    @State private var password = KeychainHelper.shared.read(key: "password") ?? ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.title)
                .bold()

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button("Log In") {
                print("🔐 Login button tapped")
                Task {
                    await auth.signIn(email: email, password: password)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

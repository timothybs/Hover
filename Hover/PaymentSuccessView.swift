import SwiftUI

struct PaymentSuccessView: View {
    let amount: Double
    let paymentMethod: String // "tap-to-pay" or "open-banking"
    let extraMessage: String? // optional message like change due
    @State private var emailAddress: String = ""
    @State private var countdown: Int = 10
    @State private var isEmailEntryActive: Bool = false
    @FocusState private var isEmailFieldFocused: Bool
    // @Environment(\.dismiss) var dismiss
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("✅ Payment Successful")
                .font(.title)
                .padding(.top)

            Text("Paid \(NumberFormatter.gbpCurrency.string(from: NSNumber(value: amount)) ?? "£\(amount)")")
                .font(.headline)

            Text("via \(formattedMethodLabel())")
                .foregroundColor(.gray)
            
            if let extra = extraMessage {
                Text(extra)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            if isEmailEntryActive {
                TextField("Enter customer email", text: $emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .focused($isEmailFieldFocused)

                Button("Send Email") {
                    sendEmailReceipt()
                }
                .buttonStyle(SuccessButtonStyle())
            }

            VStack(spacing: 16) {
                Button("🖨️ Print Receipt") {
                    print("TODO: handle print")
                }
                .buttonStyle(SuccessButtonStyle())

                Button("📧 Email Receipt") {
                    isEmailEntryActive = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isEmailFieldFocused = true
                    }
                }
                .buttonStyle(SuccessButtonStyle())

                Button("💬 Text Receipt") {
                    print("TODO: handle SMS")
                }
                .buttonStyle(SuccessButtonStyle())

                Button("🟢 WhatsApp Receipt") {
                    print("TODO: handle WhatsApp")
                }
                .buttonStyle(SuccessButtonStyle())
            }
            .padding(.top)

            Spacer()

            Button("🔄 Reset (\(countdown))") {
                resetAndDismiss()
            }
            .buttonStyle(SuccessButtonStyle())
            .padding(.top)
        }
        .padding()
        .onAppear {
            startCountdown()
        }
    }

    func sendEmailReceipt() {
        guard !emailAddress.isEmpty else {
            print("❌ No email entered")
            return
        }

        let url = URL(string: "https://v0-pos-mvp.vercel.app/api/send-receipt-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "amount": amount,
            "method": paymentMethod,
            "email": emailAddress
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            print("📧 Email receipt request sent to \(emailAddress)")
            DispatchQueue.main.async {
                isEmailEntryActive = false
                startCountdown()
            }
        }.resume()
    }

    func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isEmailEntryActive {
                return
            }
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                resetAndDismiss()
            }
        }
    }

    func resetAndDismiss() {
        onReset()
        // dismiss()
    }

    func formattedMethodLabel() -> String {
        switch paymentMethod {
        case "open-banking":
            return "Open Banking"
        case "cash":
            return "Cash"
        case "tap-to-pay":
            return "Tap to Pay"
        default:
            return paymentMethod.capitalized
        }
    }
}

struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
 

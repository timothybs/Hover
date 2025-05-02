//
//  CheckoutView.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//

import SwiftUI
import StripeTerminal


class MyMobileReaderDelegate: NSObject, MobileReaderDelegate {
    func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {
        
    }
    
    func reader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        
    }
    
    func reader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        
    }
    
    func reader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: (any Error)?) {
        
    }
    
    func reader(_ reader: Reader, didReportReaderEvent event: ReaderEvent) {
        print("Reader event: \(event)")
    }

    func reader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions) {
        print("Reader input requested: \(inputOptions)")
    }

    func reader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {
        print("Reader display message: \(displayMessage)")
    }
}

class StripeTerminalManager: NSObject, ObservableObject {
    private var readerDelegate: MyMobileReaderDelegate?
    private var discoveryDelegate: _SimulatedDiscoveryDelegate?
    
    func connectAndCharge(amount: Int, currency: String = "gbp") {
        let builder = BluetoothScanDiscoveryConfigurationBuilder()
        builder.setSimulated(true)
        guard let discoveryConfig = try? builder.build() else {
            print("❌ Failed to build discovery config")
            return
        }

        readerDelegate = MyMobileReaderDelegate()

        let delegate = _SimulatedDiscoveryDelegate(onReadersUpdate: { [weak self] readers in
            guard let self = self else { return }
            guard let reader = readers.first else {
                print("No readers found.")
                return
            }

            guard let locationId = reader.locationId else {
                print("❌ Reader missing locationId")
                return
            }

            guard let connectionConfig = try? BluetoothConnectionConfigurationBuilder(delegate: self.readerDelegate!,
                locationId: locationId
            ).build() else {
                print("Failed to build connection config")
                return
            }

            Terminal.shared.connectReader(reader, connectionConfig: connectionConfig) { connectedReader, error in
                if let error = error {
                    print("Connection failed: \(error)")
                } else if let connectedReader = connectedReader {
                    print("Connected to reader: \(connectedReader.serialNumber)")
                    self.startPaymentFlow(amount: amount, currency: currency)
                }
            }
        })

        self.discoveryDelegate = delegate

        Terminal.shared.discoverReaders(discoveryConfig, delegate: delegate) { error in
            if let error = error {
                print("❌ Reader discovery failed: \(error)")
            } else {
                print("✅ Reader discovery started")
            }
        }
    }

    private func startPaymentFlow(amount: Int, currency: String) {
        let url = URL(string: "https://v0-pos-mvp.vercel.app/api/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["amount": amount, "currency": currency]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Failed to create PaymentIntent: \(error)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["client_secret"] as? String else {
                print("Invalid response")
                return
            }

            Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret, completion: { paymentIntent, error in
                if let error = error {
                    print("❌ Failed to retrieve PaymentIntent: \(error)")
                    return
                }

                guard let paymentIntent = paymentIntent else {
                    print("❌ No PaymentIntent returned")
                    return
                }

                Terminal.shared.collectPaymentMethod(paymentIntent, completion: { paymentIntent, error in
                    if let error = error {
                        print("❌ Failed to collect payment: \(error)")
                        return
                    }

                    guard let collectedIntent = paymentIntent else {
                        print("❌ No PaymentIntent collected")
                        return
                    }

                    Terminal.shared.confirmPaymentIntent(collectedIntent) { confirmedIntent, error in
                        if let error = error {
                            print("❌ Failed to confirm PaymentIntent on reader: \(error)")
                            return
                        }

                        guard let confirmedIntent = confirmedIntent,
                              let stripeId = confirmedIntent.stripeId else {
                            print("❌ Confirmed PaymentIntent is missing stripeId")
                            return
                        }

                        print("✅ Confirmed on reader. Now sending to backend for capture: \(stripeId)")
                        self.confirmPaymentIntentOnBackend(paymentIntentId: stripeId)
                    }
                })
            })
        }.resume()
    }
    
    private func confirmPaymentIntentOnBackend(paymentIntentId: String) {
        let url = URL(string: "https://v0-pos-mvp.vercel.app/api/confirm-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["payment_intent_id": paymentIntentId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ Failed to confirm payment intent: \(error)")
                return
            }

            print("✅ Payment confirmed!")
        }.resume()
    }
}

struct CheckoutView: View {
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var terminalManager = StripeTerminalManager()
    
    var subtotal: Double {
        cartManager.totalPrice()
    }
    
    var tax: Double {
        subtotal * 0.1 // 10% tax
    }
    
    var total: Double {
        subtotal + tax
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if cartManager.items.isEmpty {
                    Text("🛒 Nothing to checkout")
                        .foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Subtotal:")
                            Spacer()
                            Text(String(format: "$%.2f", subtotal))
                        }
                        HStack {
                            Text("Tax (10%):")
                            Spacer()
                            Text(String(format: "$%.2f", tax))
                        }
                        Divider()
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "$%.2f", total))
                                .font(.headline)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        // Here you'd integrate Stripe Terminal

                        connectToReaderAndCharge()
                        print("Charging \(String(format: "$%.2f", total))")
                    }) {
                        Text("Charge \(String(format: "$%.2f", total))")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("💳 Checkout")
        }
    }
    func connectToReaderAndCharge() {
        terminalManager.connectAndCharge(amount: Int(total * 100))
    }
}

class _SimulatedDiscoveryDelegate: NSObject, DiscoveryDelegate {
    let onReadersUpdate: ([Reader]) -> Void

    init(onReadersUpdate: @escaping ([Reader]) -> Void) {
        self.onReadersUpdate = onReadersUpdate
    }

    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        onReadersUpdate(readers)
    }
}

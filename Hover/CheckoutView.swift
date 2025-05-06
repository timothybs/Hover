enum PaymentRoute: Hashable, Codable {
    case tapToPaySuccess
    case openBankingSuccess
    case cashSuccess(changeDue: String)

    enum CodingKeys: CodingKey {
        case type, changeDue
    }

    enum CaseType: String, Codable {
        case tapToPaySuccess
        case openBankingSuccess
        case cashSuccess
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CaseType.self, forKey: .type)

        switch type {
        case .tapToPaySuccess:
            self = .tapToPaySuccess
        case .openBankingSuccess:
            self = .openBankingSuccess
        case .cashSuccess:
            let change = try container.decode(String.self, forKey: .changeDue)
            self = .cashSuccess(changeDue: change)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .tapToPaySuccess:
            try container.encode(CaseType.tapToPaySuccess, forKey: .type)
        case .openBankingSuccess:
            try container.encode(CaseType.openBankingSuccess, forKey: .type)
        case .cashSuccess(let changeDue):
            try container.encode(CaseType.cashSuccess, forKey: .type)
            try container.encode(changeDue, forKey: .changeDue)
        }
    }
}

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
    private var paymentCompletion: ((Bool) -> Void)?
    var auth: AuthManager
    
    init(auth: AuthManager) {
        self.auth = auth
        super.init()
    }
    
    func connectAndCharge(amount: Int, currency: String = "gbp", completion: @escaping (Bool) -> Void) {
        // If already connected, skip discovery and start payment flow
        if Terminal.shared.connectionStatus == .connected {
            print("✅ Already connected to reader. Skipping discovery.")
            self.startPaymentFlow(amount: amount, currency: currency)
            return
        }
        self.paymentCompletion = { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
        let builder = BluetoothScanDiscoveryConfigurationBuilder()
        builder.setSimulated(true)
        guard let discoveryConfig = try? builder.build() else {
            print("❌ Failed to build discovery config")
            completion(false)
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
                    DispatchQueue.main.async {
                        self.paymentCompletion?(false)
                    }
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
                DispatchQueue.main.async {
                    self.paymentCompletion?(false)
                }
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
        let stripeAccount = auth.merchant?.stripe_account_id ?? ""
        let body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "stripeAccount": stripeAccount
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Failed to create PaymentIntent: \(error)")
                DispatchQueue.main.async {
                    self.paymentCompletion?(false)
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let clientSecret = json["client_secret"] as? String else {
                print("Invalid response")
                DispatchQueue.main.async {
                    self.paymentCompletion?(false)
                }
                return
            }

            Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret, completion: { paymentIntent, error in
                if let error = error {
                    print("❌ Failed to retrieve PaymentIntent: \(error)")
                    DispatchQueue.main.async {
                        self.paymentCompletion?(false)
                    }
                    return
                }

                guard let paymentIntent = paymentIntent else {
                    print("❌ No PaymentIntent returned")
                    DispatchQueue.main.async {
                        self.paymentCompletion?(false)
                    }
                    return
                }

                Terminal.shared.collectPaymentMethod(paymentIntent, completion: { paymentIntent, error in
                    if let error = error {
                        let terminalError = error as NSError
                        if terminalError.domain == ErrorDomain,
                           terminalError.code == 2020 {
                            print("⚠️ Payment was cancelled by the user")
                        } else {
                            print("❌ Failed to collect payment: \(error)")
                        }
                        DispatchQueue.main.async {
                            self.paymentCompletion?(false)
                        }
                        return
                    }

                    guard let collectedIntent = paymentIntent else {
                        print("❌ No PaymentIntent collected")
                        DispatchQueue.main.async {
                            self.paymentCompletion?(false)
                        }
                        return
                    }

                    Terminal.shared.confirmPaymentIntent(collectedIntent) { confirmedIntent, error in
                        if let error = error {
                            print("❌ Failed to confirm PaymentIntent on reader: \(error)")
                            DispatchQueue.main.async {
                                self.paymentCompletion?(false)
                            }
                            return
                        }

                        guard let confirmedIntent = confirmedIntent,
                              let stripeId = confirmedIntent.stripeId else {
                            print("❌ Confirmed PaymentIntent is missing stripeId")
                            DispatchQueue.main.async {
                                self.paymentCompletion?(false)
                            }
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
                DispatchQueue.main.async {
                    self.paymentCompletion?(false)
                }
                return
            }

            print("✅ Payment confirmed!")
            DispatchQueue.main.async {
                self.paymentCompletion?(true)
            }
        }.resume()
    }
}

struct CheckoutView: View {
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var terminalManager: StripeTerminalManager
    @State private var showResult = false
    @State private var paymentSuccess = false
    @State private var showingCashSheet = false
    @State private var cashTendered: Double? = nil
    @State private var cashChangeDue: String? = nil
    @EnvironmentObject var auth: AuthManager
    @State private var openBankingRedirectURL: String? = nil
    @State private var openBankingPaymentIntentId: String? = nil
    @State private var openBankingPaid: Bool = false
    @State private var showPaymentSuccess = false
    @State private var paymentMethodUsed: String = ""
    @State private var extraMessage: String? = nil
    @State private var shouldRouteToSuccessAfterSheet = false
    
    init() {
        // This init will be overridden by body init, so we keep it empty
        _terminalManager = StateObject(wrappedValue: StripeTerminalManager(auth: AuthManager()))
    }
    
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
        NavigationStack {
            VStack(spacing: 20) {
                if cartManager.items.isEmpty {
                    Text("🛒 Nothing to checkout")
                        .foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Subtotal:")
                            Spacer()
                            Text(NumberFormatter.gbpCurrency.string(from: NSNumber(value: subtotal)) ?? "£\(subtotal)")
                        }
                        HStack {
                            Text("Tax (10%):")
                            Spacer()
                            Text(NumberFormatter.gbpCurrency.string(from: NSNumber(value: tax)) ?? "£\(tax)")
                        }
                        Divider()
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text(NumberFormatter.gbpCurrency.string(from: NSNumber(value: total)) ?? "£\(total)")
                                .font(.headline)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        terminalManager.connectAndCharge(amount: Int(total * 100)) { success in
                            DispatchQueue.main.async {
                                if success {
                                    paymentSuccess = true
                                    paymentMethodUsed = "tap-to-pay"
                                    extraMessage = nil
                                    showPaymentSuccess = true
                                } else {
                                    cartManager.clearCart()
                                    paymentSuccess = false
                                    openBankingPaid = false
                                    openBankingRedirectURL = nil
                                    openBankingPaymentIntentId = nil
                                    // No-op needed for path
                                }
                            }
                        }
                        print("Charging \(NumberFormatter.gbpCurrency.string(from: NSNumber(value: total)) ?? "£\(total)")")
                    }) {
                        Text("Charge \(NumberFormatter.gbpCurrency.string(from: NSNumber(value: total)) ?? "£\(total)")")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    Button(action: {
                        createOpenBankingPayment()
                    }) {
                        Text("Charge Bank")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    Button("💵 Pay Cash") {
                        showingCashSheet = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // QR code display for open banking redirect URL
                if let redirectURL = openBankingRedirectURL {
                    if let qrImage = generateQRCode(from: redirectURL) {
                        Text("Scan this:")
                            .font(.headline)
                            .padding(.top)
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding()
                    }
                }
                // Show Open Banking payment success message
                if openBankingPaid {
                    Text("✅ Open Banking payment received!")
                        .font(.title2)
                        .foregroundColor(.green)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                terminalManager.auth = auth
            }
            .onChange(of: showingCashSheet) { isPresented in
                if !isPresented && shouldRouteToSuccessAfterSheet {
                    shouldRouteToSuccessAfterSheet = false
                }
            }
            // Inline Cash Payment UI
            if showingCashSheet {
                VStack(spacing: 16) {
                    Text("Enter Cash Tendered")
                        .font(.headline)

                    HStack {
                        ForEach([5.0, 10.0, 15.0, 20.0], id: \.self) { amount in
                            Button("£\(Int(amount))") {
                                cashTendered = amount
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }

                    if let tendered = cashTendered {
                        let change = tendered - total
                        Text("Change due: £\(String(format: "%.2f", max(0, change)))")
                            .font(.title2)
                            .foregroundColor(change >= 0 ? .green : .red)
                            .padding(.top)

                        Button("Confirm Payment") {
                            let changeString = "Change due: £\(String(format: "%.2f", max(0, change)))"
                            cashChangeDue = changeString
                            paymentSuccess = true
                            showingCashSheet = false
                            paymentMethodUsed = "cash"
                            extraMessage = changeString
                            showPaymentSuccess = true
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $showPaymentSuccess) {
            PaymentSuccessView(
                amount: total,
                paymentMethod: paymentMethodUsed,
                extraMessage: extraMessage,
                onReset: {
                    cartManager.clearCart()
                    paymentSuccess = false
                    openBankingPaid = false
                    openBankingRedirectURL = nil
                    openBankingPaymentIntentId = nil
                    cashChangeDue = nil
                    showPaymentSuccess = false
                }
            )
        }
    }
    func connectToReaderAndCharge() {
        terminalManager.connectAndCharge(amount: Int(total * 100)) { _ in }
    }
    func createOpenBankingPayment() {
        guard let stripeAccount = auth.merchant?.stripe_account_id else {
            print("❌ Missing stripe_account_id")
            return
        }

        // Step 1: Create the PaymentIntent
        let createUrl = URL(string: "https://v0-pos-mvp.vercel.app/api/create-openbanking-payment")!
        var createRequest = URLRequest(url: createUrl)
        createRequest.httpMethod = "POST"
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "amount": Int(total * 100),
            "currency": "gbp",
            "stripeAccount": stripeAccount
        ]
        createRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: createRequest) { data, _, error in
            if let error = error {
                print("❌ Failed to create PaymentIntent:", error.localizedDescription)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let intentId = json["id"] as? String else {
                print("❌ Invalid response from create endpoint")
                return
            }

            print("✅ Created PaymentIntent:", intentId)
            DispatchQueue.main.async {
                self.openBankingPaymentIntentId = intentId
            }

            // Step 2: Confirm the PaymentIntent to get redirect URL
            let confirmUrl = URL(string: "https://v0-pos-mvp.vercel.app/api/confirm-openbanking-payment")!
            var confirmRequest = URLRequest(url: confirmUrl)
            confirmRequest.httpMethod = "POST"
            confirmRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let confirmPayload: [String: Any] = [
                "payment_intent_id": intentId,
                "stripeAccount": stripeAccount
            ]
            confirmRequest.httpBody = try? JSONSerialization.data(withJSONObject: confirmPayload)

            URLSession.shared.dataTask(with: confirmRequest) { confirmData, _, confirmError in
                if let confirmError = confirmError {
                    print("❌ Failed to confirm PaymentIntent:", confirmError.localizedDescription)
                    return
                }

                // Logging before JSON parsing
                guard let confirmData = confirmData else {
                    print("❌ No confirmData returned")
                    return
                }
                if let raw = String(data: confirmData, encoding: .utf8) {
                    print("📦 Confirm response raw JSON:", raw)
                }
                guard let confirmJson = try? JSONSerialization.jsonObject(with: confirmData) as? [String: Any] else {
                    print("❌ Could not parse JSON")
                    return
                }
                guard let redirectURL = confirmJson["redirect_url"] as? String else {
                    print("❌ redirect_url missing in parsed JSON:", confirmJson)
                    return
                }

                print("✅ Open Banking redirect URL:", redirectURL)

                DispatchQueue.main.async {
                    self.openBankingRedirectURL = redirectURL
                    self.pollOpenBankingStatus()
                }
            }.resume()
        }.resume()
    }

    func pollOpenBankingStatus() {
        guard let intentId = openBankingPaymentIntentId,
              let stripeAccount = auth.merchant?.stripe_account_id else { return }

        let url = URL(string: "https://v0-pos-mvp.vercel.app/api/get-payment-intent-status")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "payment_intent_id": intentId,
            "stripeAccount": stripeAccount
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                print("❌ Failed to fetch PaymentIntent status")
                return
            }

            print("📡 PaymentIntent status: \(status)")
            if status == "succeeded" {
                DispatchQueue.main.async {
                    self.openBankingPaid = true
                    self.paymentMethodUsed = "open-banking"
                    self.extraMessage = nil
                    self.showPaymentSuccess = true
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.pollOpenBankingStatus()
                }
            }
        }.resume()
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }

        return nil
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


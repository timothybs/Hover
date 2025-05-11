//
//  OrderView.swift
//  Hover
//
//  Created by Timothy Sumner on 07/05/2025.
//



import SwiftUI

struct OrderView: View {
    let order: [String: Any]
    
    @State private var showingRefundSheet = false
    @State private var selectedRefundItems: Set<Int> = []
    @State private var showingRefundError = false
    @State private var refundedItemIndexes: Set<Int> = []
    
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Order Details")
                    .font(.title)
                    .bold()

                Text("Total: £\(order["total"] as? Double ?? 0.0, specifier: "%.2f")")
                Text("Payment Method: \(order["payment_method"] as? String ?? "-")")
                Text("Created At: \(order["created_at"] as? String ?? "-")")

                Divider()

                if let items = order["items"] as? [[String: Any]] {
                    ForEach(0..<items.count, id: \.self) { index in
                        let item = items[index]
                        let product = item["product"] as? [String: Any] ?? [:]
                        let name = product["name"] as? String ?? "Unknown"
                        let quantity = item["quantity"] as? Int ?? 1

                        HStack {
                            Text(name)
                                .bold()
                            Spacer()
                            Text("x\(quantity)")
                            if refundedItemIndexes.contains(index) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No items found.")
                        .foregroundColor(.gray)
                }
            }
            VStack(spacing: 12) {
                Button("Refund") {
                    showingRefundSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("Exchange") {
                    // TODO: Handle exchange logic
                    print("Exchange requested for order")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
            .padding()
        }
        .onAppear {
            Task {
                await loadRefundedItems()
            }
        }
        .navigationTitle("Order")
        .sheet(isPresented: $showingRefundSheet) {
            NavigationStack {
                List {
                    if let items = order["items"] as? [[String: Any]] {
                        ForEach(0..<items.count, id: \.self) { index in
                            let item = items[index]
                            let product = item["product"] as? [String: Any] ?? [:]
                            let name = product["name"] as? String ?? "Unknown"
                            let quantity = item["quantity"] as? Int ?? 1

                            HStack {
                                Text("\(name) x\(quantity)")
                                Spacer()
                                if selectedRefundItems.contains(index) {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedRefundItems.contains(index) {
                                    selectedRefundItems.remove(index)
                                } else {
                                    selectedRefundItems.insert(index)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Select Items")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Refund") {
                            // TODO: Call refund logic
                            handleRefund()
                            showingRefundSheet = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingRefundSheet = false
                        }
                    }
                }
            }
        }
        .alert("Refund Not Sent to Stripe", isPresented: $showingRefundError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No Stripe payment intent ID found. This order may have been paid in cash or through an unsupported method.")
        }
    }

    // MARK: - Refund Handler
    func handleRefund() {
        guard let orderId = order["id"] as? String else {
            print("❌ Missing order ID")
            return
        }

        let selectedItems: [[String: Any]] = selectedRefundItems.compactMap { index in
            guard let items = order["items"] as? [[String: Any]],
                  index < items.count else { return nil }
            var item = items[index]
            item["index"] = index
            return item
        }

        let refundAmount = selectedItems.reduce(0.0) { total, item in
            let product = item["product"] as? [String: Any] ?? [:]
            let price = (product["price"] as? Double ?? item["price"] as? Double ?? 0.0)
            let quantity = item["quantity"] as? Int ?? 1
            return total + (price * Double(quantity))
        }
        let amountInPence = Int(refundAmount * 100)

        let refundPayload: [String: Any] = [
            "order_id": orderId,
            "items": selectedItems,
            "refunded_at": ISO8601DateFormatter().string(from: Date()),
            "total": order["total"] ?? 0
        ]

        // Send refund to Stripe via backend
        let stripeId = order["stripe_id"] as? String ??
                       order["payment_intent_id"] as? String ??
                       (order["order"] as? [String: Any])?["payment_intent_id"] as? String

        if let stripeId {
            print("🔁 Attempting refund with Stripe ID:", stripeId)
            print("📤 Sending refund to Stripe for ID:", stripeId)

            guard let refundURL = URL(string: "https://v0-pos-mvp.vercel.app/api/refund") else { return }

            var stripeRequest = URLRequest(url: refundURL)
            stripeRequest.httpMethod = "POST"
            stripeRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let stripeAccountId = authManager.merchant?.stripeAccountId ?? ""
            stripeRequest.httpBody = try? JSONSerialization.data(withJSONObject: [
                "payment_intent_id": stripeId,
                "stripe_account_id": stripeAccountId,
                "amount": amountInPence
            ])

            URLSession.shared.dataTask(with: stripeRequest) { data, response, error in
                if let error = error {
                    print("❌ Stripe refund request failed:", error)
                    showingRefundError = true
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let refund = json["refund"] as? [String: Any],
                      let status = refund["status"] as? String else {
                    print("❌ Invalid or missing refund response")
                    showingRefundError = true
                    return
                }

                print("✅ Stripe refund status:", status)

                if status == "succeeded" || status == "pending" {
                    logRefundToSupabase(refundPayload)
                } else {
                    print("⚠️ Refund not successful. Status:", status)
                    showingRefundError = true
                }
            }.resume()
        } else {
            print("⚠️ No Stripe ID found — likely a cash or open banking order.")
            print("🧾 Full order dump for debug:", order)
            showingRefundError = true
            logRefundToSupabase(refundPayload)
        }
    }

    func logRefundToSupabase(_ payload: [String: Any]) {
        guard
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: "\(supabaseURL)/rest/v1/refunds")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [payload])

        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("✅ Refund logged to Supabase")
        }.resume()
    }

    func loadRefundedItems() async {
        guard
            let orderId = order["id"] as? String,
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: "\(supabaseURL)/rest/v1/refunds?order_id=eq.\(orderId)&select=items")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try! await URLSession.shared.data(for: request)

        if let refundArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var indexes = Set<Int>()
            for refund in refundArray {
                if let items = refund["items"] as? [[String: Any]] {
                    for item in items {
                        if let index = item["index"] as? Int {
                            indexes.insert(index)
                        }
                    }
                }
            }
            refundedItemIndexes = indexes
        }
    }
}

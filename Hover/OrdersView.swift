import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var orders: [[String: Any]] = []
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search orders", text: $searchText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    Button(action: {
                        // future: trigger barcode scanner
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .imageScale(.large)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                List(orders.indices, id: \.self) { i in
                    let order = orders[i]
                    NavigationLink(destination: OrderView(order: order)) {
                        VStack(alignment: .leading) {
                            Text("Total: £\(order["total"] as? Double ?? 0.0, specifier: "%.2f")")
                                .font(.headline)
                            Text("Method: \(order["payment_method"] as? String ?? "-")")
                                .font(.subheadline)
                            Text("Date: \(String(describing: order["created_at"] ?? ""))")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Button("Print Test Receipt") {
                  //  ReceiptPrinter.shared.printTestReceipt()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .onAppear(perform: fetchOrders)
        }
    }

    func fetchOrders() {
        guard
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: "\(supabaseURL)/rest/v1/orders?select=*&order=created_at.desc")
        else {
            print("❌ Supabase config missing")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let accessToken = auth.session?.accessToken ?? anonKey
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 GET /orders status: \(httpResponse.statusCode)")
            }

            if let error = error {
                print("❌ Failed to fetch orders: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("❌ No data returned from Supabase")
                return
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("📨 Raw JSON:", raw)
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    DispatchQueue.main.async {
                        self.orders = json
                        print("✅ Orders fetched: \(json.count)")
                    }
                } else {
                    print("❌ JSON response not in expected format")
                }
            } catch {
                print("❌ JSON parse error: \(error.localizedDescription)")
            }
        }.resume()
    }
}

#Preview {
    OrdersView()
}

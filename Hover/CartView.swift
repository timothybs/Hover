import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productCache: ProductCache
    @State private var showScanner = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    if cartManager.items.isEmpty {
                        Text("🛒 Your cart is empty")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(cartManager.items.keys.sorted(by: { $0.name < $1.name }), id: \.self) { product in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .font(.headline)
                                    Text(NumberFormatter.gbpCurrency.string(from: NSNumber(value: product.price)) ?? "£\(product.price)")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text("Qty: \(cartManager.items[product] ?? 0)")
                            }
                        }
                    }
                }

                Button(action: {
                    showScanner = true
                }) {
                    Text("📷 Scan Barcode")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("🛒 Cart")

            .sheet(isPresented: $showScanner) {
                BarcodeScannerScreen()
                    .environmentObject(cartManager)
                    .environmentObject(productCache)
            }
        }
    }
}

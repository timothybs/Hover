import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        NavigationView {
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
                                Text(String(format: "$%.2f each", product.price))
                                    .font(.subheadline)
                            }
                            Spacer()
                            Text("Qty: \(cartManager.items[product] ?? 0)")
                        }
                    }
                }
            }
            .navigationTitle("🛒 Cart")
        }
    }
}

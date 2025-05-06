import SwiftUI

struct OrdersView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Orders")
                    .font(.largeTitle)
                    .padding()
                Button("Test Print") {
//                    ReceiptPrinter.shared.printTestReceipt()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
}

#Preview {
    OrdersView()
}

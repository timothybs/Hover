//
//  BarcodeScannerView.swift
//  Hover
//
//  Created by Timothy Sumner on 02/05/2025.
//


import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: BarcodeScannerView

        init(parent: BarcodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let code = metadataObject.stringValue {
                print("✅ Scanned barcode: \(code)")
                parent.onScan(code)
            }
        }
    }

    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            print("❌ Could not access camera input")
            return controller
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = controller.view.layer.bounds
        controller.view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct BarcodeScannerScreen: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productCache: ProductCache
    @State private var lastScannedCode: String? = nil

    var body: some View {
        BarcodeScannerView { scannedCode in
            guard scannedCode != lastScannedCode else { return }
            lastScannedCode = scannedCode

            print("Scanned code: \(scannedCode)")

            if let product = productCache.product(for: scannedCode) {
                print("🛒 Found locally cached product: \(product.name)")
                cartManager.add(product: product)
            } else {
                print("⚠️ No match found in local product cache")
            }
            dismiss()
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Shared NumberFormatter for GBP currency formatting
extension NumberFormatter {
    static let gbpCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()
}

@MainActor
class ProductCache: ObservableObject {
    @Published var productsByBarcode: [String: Product] = [:]

    func loadAllProducts() async {
        guard
            let baseUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            print("❌ Missing Supabase config")
            return
        }

        print("📥 Fetching all shopify_products...")

        var offset = 0
        let pageSize = 1000
        var totalFetched = 0

        while true {
            let pagedURL = URL(string: "\(baseUrl)/rest/v1/shopify_products?select=*&limit=\(pageSize)&offset=\(offset)")!
            var request = URLRequest(url: pagedURL)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("items", forHTTPHeaderField: "Range-Unit")
            request.setValue("\(offset)-\(offset + pageSize - 1)", forHTTPHeaderField: "Range")
            request.setValue("count=exact", forHTTPHeaderField: "Prefer")

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                print("❌ Network error at offset \(offset):", error.localizedDescription)
                break
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Status: \(httpResponse.statusCode) for offset \(offset)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("⚠️ Failed to decode page at offset \(offset)")
                break
            }

            let pageCount = json.count
            totalFetched += pageCount
            print("📦 Fetched \(pageCount) products from offset \(offset)")

            for item in json {
                if let barcode = item["variant_barcode"] as? String,
                   let title = item["title"] as? String,
                   let price = item["variant_price"] as? Double {
                    productsByBarcode[barcode] = Product(id: barcode, name: title, price: price)
                }
            }

            if pageCount < pageSize { break }
            offset += pageSize
        }

        print("✅ Cached \(productsByBarcode.count) total products.")
    }

    func product(for barcode: String) -> Product? {
        return productsByBarcode[barcode]
    }
}

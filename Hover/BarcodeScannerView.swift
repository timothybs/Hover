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

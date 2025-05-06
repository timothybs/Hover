////
////  ReceiptPrinter.swift
////  Hover
////
////  Created by Timothy Sumner on 04/05/2025.
////
//
//
//import Foundation
//
//
//class ReceiptPrinter: NSObject {
//    static let shared = ReceiptPrinter()
//    
//    private var printer: Epos2Printer?
//
//    func printTestReceipt() {
//        // Create printer instance
//        printer = Epos2Printer(printerSeries: EPOS2_PRINTER_TM_M30.rawValue, lang: EPOS2_MODEL_ANK.rawValue)
//        guard let printer = printer else {
//            print("❌ Could not initialize printer.")
//            return
//        }
//        
//        printer.setReceiveEventDelegate(self)
//
//        // Discover printer by Bluetooth autoconnect
//        let target = "BT:TM-m30_XXXXXX" // Replace with your printer's name (or use Epos2Discovery later)
//        let result = printer.connect(target, timeout: Int(EPOS2_PARAM_DEFAULT))
//
//        if result != EPOS2_SUCCESS.rawValue {
//            print("❌ Failed to connect: \(result)")
//            return
//        }
//
//        printer.beginTransaction()
//
//        // Add text
//        printer.addText("Hello from Hover!\n\n")
//        printer.addCut(EPOS2_CUT_FEED.rawValue)
//
//        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
//        if sendResult != EPOS2_SUCCESS.rawValue {
//            print("❌ Failed to send print job: \(sendResult)")
//        }
//    }
//}
//
//extension ReceiptPrinter: Epos2PtrReceiveDelegate {
//    func onPtrReceive(_ printerObj: Epos2Printer!, code: Int32, status: Epos2PrinterStatusInfo!, printJobId: String!) {
//        <#code#>
//    }
//    
//    func onPtrReceive(_ printerObj: Epos2Printer!, code: Int32, status: Epos2PrinterStatusInfo!) {
//        print("✅ Print completed with code: \(code)")
//        printer?.disconnect()
//        printer?.clearCommandBuffer()
//        printer = nil
//    }
//}

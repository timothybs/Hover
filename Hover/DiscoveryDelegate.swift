//
//  SimulatedDiscoveryDelegate.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import StripeTerminal

class SimulatedDiscoveryDelegate: NSObject, DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        print("Discovered readers: \(readers.map { $0.label })")
    }
}
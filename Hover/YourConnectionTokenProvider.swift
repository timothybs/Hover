//
//  YourConnectionTokenProvider.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import Foundation
import StripeTerminal

class YourConnectionTokenProvider: NSObject, ConnectionTokenProvider {
    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        // Replace this with your backend call that returns a Stripe connection token
        // For now, we'll simulate failure until backend is ready
        completion(nil, NSError(domain: "Hover", code: 0, userInfo: [NSLocalizedDescriptionKey: "Simulated token fetch"]))
    }
}
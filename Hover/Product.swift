//
//  Product.swift
//  Hover
//
//  Created by Timothy Sumner on 01/05/2025.
//


import Foundation

struct Product: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let price: Double
}

extension Product {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

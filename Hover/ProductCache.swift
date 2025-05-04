import Foundation

@MainActor
class ProductCache: ObservableObject {
    @Published var productsByBarcode: [String: Product] = [:]
    
    func loadAllProducts() async {
        guard
            let baseUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            print("❌ Missing Supabase config in Info.plist")
            return
        }

        var offset = 0
        let limit = 100
        var allProducts: [String: Product] = [:]

        outerLoop: while true {
            let url = URL(string: "\(baseUrl)/rest/v1/shopify_products?select=*")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(anonKey, forHTTPHeaderField: "apikey")
            request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.addValue("items", forHTTPHeaderField: "Range-Unit")
            request.addValue("\(offset)-\(offset + limit - 1)", forHTTPHeaderField: "Range")
            request.addValue("count=exact", forHTTPHeaderField: "Prefer")
            
            // print("Requesting URL: \(request.url?.absoluteString ?? "nil")")
            // print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            
            var attempt = 0
            let maxAttempts = 3
            var success = false
            
            while attempt < maxAttempts && !success {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        // print("Failed to fetch shopify_products, no HTTP response")
                        attempt += 1
                        continue
                    }
                    // print("Fetching products with offset \(offset), status: \(httpResponse.statusCode)")
                    guard httpResponse.statusCode == 206 || httpResponse.statusCode == 200 else {
                        // print("Failed to fetch shopify_products, status code: \(httpResponse.statusCode)")
                        attempt += 1
                        continue
                    }
                    
                    if let productsArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        // print("Decoded \(productsArray.count) products")
                        if productsArray.isEmpty {
                            success = true
                            break
                        }
                        
                        for dict in productsArray {
                            if let id = dict["variant_barcode"] as? String,
                               let name = dict["title"] as? String,
                               let price = dict["variant_price"] as? Double {
                                let product = Product(id: id, name: name, price: price)
                                allProducts[id] = product
                            }
                        }
                        print("Loaded page with offset \(offset), products count: \(productsArray.count)")
                        
                        if productsArray.count < limit {
                            break outerLoop
                        }
                        
                        success = true
                    } else {
                        // print("Invalid shopify_products data format")
                        attempt += 1
                        continue
                    }
                } catch {
                    // print("Failed to load shopify_products on attempt \(attempt + 1): \(error)")
                    attempt += 1
                    continue
                }
            }
            
            if !success {
                print("Failed to fetch products after \(maxAttempts) attempts for offset \(offset). Aborting.")
                break
            }
            
            offset += limit
        }
        
        if allProducts.isEmpty {
            print("⚠️ Warning: Loaded products cache is empty after loading attempts.")
        } else {
            print("Successfully loaded total \(allProducts.count) products into cache")
        }
        productsByBarcode = allProducts
    }
    
    func product(for barcode: String) -> Product? {
        return productsByBarcode[barcode]
    }
}

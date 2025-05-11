import Foundation

struct Merchant: Decodable {
    let id: String
    let stripeAccountId: String
    let terminalLocationId: String?
    let userId: String
    let status: String
    let settings: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case stripeAccountId = "stripe_account_id"
        case terminalLocationId = "terminal_location_id"
        case userId = "user_id"
        case status
        case settings
    }
}

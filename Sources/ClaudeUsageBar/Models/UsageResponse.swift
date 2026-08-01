import Foundation

/// One rate-limit window (5h or 7d) from the usage endpoint.
struct UsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

/// `GET /api/oauth/usage` response. Every field is optional — the endpoint
/// is undocumented and its shape has drifted across plan tiers before.
struct UsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

import Foundation

/// Aggregate stats for a species across the station's full detection history.
/// Mirrors the BirdNET-Go `GET /api/v2/analytics/species/summary` payload.
struct SpeciesSummary: Codable, Equatable, Sendable {
    var scientificName: String
    var commonName: String
    var speciesCode: String?
    var count: Int
    var firstHeard: String?
    var lastHeard: String?
    var avgConfidence: Double?
    var maxConfidence: Double?
    var thumbnailURL: String?

    private enum CodingKeys: String, CodingKey {
        case scientificName = "scientific_name"
        case commonName = "common_name"
        case speciesCode = "species_code"
        case count
        case firstHeard = "first_heard"
        case lastHeard = "last_heard"
        case avgConfidence = "avg_confidence"
        case maxConfidence = "max_confidence"
        case thumbnailURL = "thumbnail_url"
    }
}

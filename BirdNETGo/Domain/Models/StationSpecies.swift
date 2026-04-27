import Foundation

struct StationSpecies: Codable, Equatable, Identifiable, Sendable {
    var commonName: String
    var scientificName: String
    var speciesCode: String?
    var rarity: String?
    var detectionCount: Int?
    var latestDetectionTimestamp: String?
    var thumbnailURL: URL?

    var id: String {
        (speciesCode ?? scientificName.nonEmptyString ?? commonName).lowercased()
    }

    init(
        commonName: String,
        scientificName: String,
        speciesCode: String? = nil,
        rarity: String? = nil,
        detectionCount: Int? = nil,
        latestDetectionTimestamp: String? = nil,
        thumbnailURL: URL? = nil
    ) {
        self.commonName = commonName.nonEmptyString ?? scientificName
        self.scientificName = scientificName.nonEmptyString ?? commonName
        self.speciesCode = speciesCode.nonEmptyString
        self.rarity = rarity.nonEmptyString
        self.detectionCount = detectionCount
        self.latestDetectionTimestamp = latestDetectionTimestamp.nonEmptyString
        self.thumbnailURL = thumbnailURL
    }

    init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        if let name = try? singleValueContainer.decode(String.self), let displayName = name.nonEmptyString {
            self.init(commonName: displayName, scientificName: displayName)
            return
        }

        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        let commonName = container.string(for: ["commonName", "common_name", "common", "displayName", "display_name", "name"])
        let scientificName = container.string(for: ["scientificName", "scientific_name", "latinName", "latin_name", "sciName", "species"])
        let speciesCode = container.string(for: ["speciesCode", "species_code", "code", "alphaCode", "alpha_code"])
        let fallbackName = commonName ?? scientificName ?? speciesCode ?? "Unknown species"

        self.init(
            commonName: commonName ?? fallbackName,
            scientificName: scientificName ?? fallbackName,
            speciesCode: speciesCode,
            rarity: container.string(for: ["rarity", "status", "occurrence"]),
            detectionCount: container.int(for: ["detectionCount", "detection_count", "detections", "count", "totalDetections", "total_detections"]),
            latestDetectionTimestamp: container.string(for: ["latestDetection", "latest_detection", "latestDetectionAt", "latest_detection_at", "lastSeen", "last_seen", "lastDetection", "last_detection", "lastDetectedAt", "last_detected_at"]),
            thumbnailURL: container.url(for: ["thumbnailURL", "thumbnail_url", "thumbnail", "imageURL", "image_url", "image"])
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commonName, forKey: .commonName)
        try container.encode(scientificName, forKey: .scientificName)
        try container.encodeIfPresent(speciesCode, forKey: .speciesCode)
        try container.encodeIfPresent(rarity, forKey: .rarity)
        try container.encodeIfPresent(detectionCount, forKey: .detectionCount)
        try container.encodeIfPresent(latestDetectionTimestamp, forKey: .latestDetectionTimestamp)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
    }

    private enum CodingKeys: String, CodingKey {
        case commonName
        case scientificName
        case speciesCode
        case rarity
        case detectionCount
        case latestDetectionTimestamp
        case thumbnailURL
    }
}

struct StationSpeciesList: Decodable, Equatable, Sendable {
    var species: [StationSpecies]

    init(from decoder: Decoder) throws {
        if let species = try? [StationSpecies](from: decoder) {
            self.species = species
            return
        }

        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        for key in ["species", "results", "items"] {
            if let species = try? container.decode([StationSpecies].self, forKey: FlexibleCodingKey(key)) {
                self.species = species
                return
            }
        }

        if let species = try? container.decode([StationSpecies].self, forKey: FlexibleCodingKey("data")) {
            self.species = species
            return
        }

        if let nested = try? container.decode(NestedStationSpeciesList.self, forKey: FlexibleCodingKey("data")) {
            self.species = nested.species
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a species array or species response envelope.")
        )
    }
}

private struct NestedStationSpeciesList: Decodable {
    var species: [StationSpecies]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        for key in ["species", "results", "items"] {
            if let species = try? container.decode([StationSpecies].self, forKey: FlexibleCodingKey(key)) {
                self.species = species
                return
            }
        }

        self.species = []
    }
}

private struct FlexibleCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == FlexibleCodingKey {
    func string(for keys: [String]) -> String? {
        for key in keys {
            if let value = try? decode(String.self, forKey: FlexibleCodingKey(key)).nonEmptyString {
                return value
            }
        }

        return nil
    }

    func int(for keys: [String]) -> Int? {
        for key in keys {
            let codingKey = FlexibleCodingKey(key)
            if let value = try? decode(Int.self, forKey: codingKey) {
                return value
            }

            if let value = try? decode(Double.self, forKey: codingKey) {
                return Int(value.rounded())
            }

            if let value = try? decode(String.self, forKey: codingKey), let intValue = Int(value) {
                return intValue
            }
        }

        return nil
    }

    func url(for keys: [String]) -> URL? {
        for key in keys {
            if let value = try? decode(URL.self, forKey: FlexibleCodingKey(key)) {
                return value
            }

            if let value = try? decode(String.self, forKey: FlexibleCodingKey(key)), let url = URL(string: value) {
                return url
            }
        }

        return nil
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyString: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        return value
    }
}

private extension String {
    var nonEmptyString: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
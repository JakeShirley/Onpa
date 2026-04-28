import Foundation
import SwiftUI

@MainActor
final class SpeciesViewModel: ObservableObject {
    @Published private(set) var stationProfile: StationProfile?
    @Published private(set) var species: [SpeciesListEntry] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: StatusKind = .neutral
    @Published private(set) var isLoading = false
    @Published private(set) var didLoad = false

    private let detectionSummaryLimit = 100
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var hasStation: Bool {
        stationProfile != nil
    }

    func load(environment: AppEnvironment) async {
        guard !didLoad else {
            return
        }

        didLoad = true
        await refresh(environment: environment)
    }

    func refresh(environment: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let profile = try await loadStationProfile(environment: environment) else {
                stationProfile = nil
                species = []
                statusMessage = nil
                return
            }

            stationProfile = profile

            var catalog: [StationSpecies] = []
            var detections: [BirdDetection] = []
            var catalogError: Error?
            var detectionsError: Error?

            do {
                catalog = try await environment.apiClient.species(station: profile)
            } catch {
                if Self.isCancellation(error) { return }
                catalogError = error
            }

            do {
                detections = try await environment.apiClient.recentDetections(station: profile, limit: detectionSummaryLimit)
            } catch {
                if Self.isCancellation(error) { return }
                detectionsError = error
            }

            guard !catalog.isEmpty || !detections.isEmpty else {
                if let error = detectionsError ?? catalogError {
                    await loadCachedSpeciesAfterError(error, for: profile, environment: environment)
                } else {
                    species = []
                    statusMessage = String(localized: "No detected species.")
                    statusKind = .neutral
                }
                return
            }

            species = makeEntries(catalog: catalog, detections: detections)
            if let detectionsError, detections.isEmpty {
                setMessage(String(localized: "Showing station species catalog without recent detection summaries: \(detectionsError.userFacingMessage)"), kind: .warning)
            } else {
                statusMessage = species.isEmpty ? String(localized: "No detected species.") : nil
                statusKind = .neutral
            }

            await cacheIgnoringErrors(SpeciesSnapshot(catalog: catalog, detections: detections), for: profile, environment: environment)
        } catch {
            if Self.isCancellation(error) { return }
            if let profile = stationProfile {
                await loadCachedSpeciesAfterError(error, for: profile, environment: environment)
            } else {
                species = []
                setMessage(error.userFacingMessage, kind: .error)
            }
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func loadStationProfile(environment: AppEnvironment) async throws -> StationProfile? {
        if let overrideURL = environment.configuration.stationURLOverride {
            return StationProfile.manual(baseURL: overrideURL)
        }

        return try await environment.stationProfileStore.loadActiveProfile() ?? environment.configuration.localNetworkTestProfile
    }

    private func cache(_ snapshot: SpeciesSnapshot, for profile: StationProfile, environment: AppEnvironment) async throws {
        let data = try encoder.encode(snapshot)
        try await environment.localCacheStore.saveData(data, for: cacheKey(for: profile))
    }

    private func cacheIgnoringErrors(_ snapshot: SpeciesSnapshot, for profile: StationProfile, environment: AppEnvironment) async {
        do {
            try await cache(snapshot, for: profile, environment: environment)
        } catch {
            // Caching failures should not surface to the user or trigger the cached-fallback path.
        }
    }

    private func loadCachedSpeciesAfterError(_ error: Error, for profile: StationProfile, environment: AppEnvironment) async {
        do {
            if let data = try await environment.localCacheStore.loadData(for: cacheKey(for: profile)) {
                let snapshot = try decoder.decode(SpeciesSnapshot.self, from: data)
                species = makeEntries(catalog: snapshot.catalog, detections: snapshot.detections)
                setMessage(String(localized: "Showing cached species."), kind: .warning)
            } else {
                species = []
                setMessage(error.userFacingMessage, kind: .error)
            }
        } catch {
            species = []
            setMessage(error.userFacingMessage, kind: .error)
        }
    }

    private func cacheKey(for profile: StationProfile) -> LocalCacheKey {
        LocalCacheKey(namespace: "species", identifier: "detected-\(profile.baseURL.absoluteString)")
    }

    private func makeEntries(catalog: [StationSpecies], detections: [BirdDetection]) -> [SpeciesListEntry] {
        let summaries = detectionSummaries(from: detections)
        var seenKeys = Set<String>()
        var entries = catalog.map { species in
            let summary = summaries[summaryKey(scientificName: species.scientificName, commonName: species.commonName, speciesCode: species.speciesCode)]
            seenKeys.insert(summaryKey(scientificName: species.scientificName, commonName: species.commonName, speciesCode: species.speciesCode))
            return SpeciesListEntry(species: species, summary: summary)
        }

        for summary in summaries.values where !seenKeys.contains(summary.key) {
            entries.append(
                SpeciesListEntry(
                    species: StationSpecies(
                        commonName: summary.commonName,
                        scientificName: summary.scientificName,
                        speciesCode: summary.speciesCode
                    ),
                    summary: summary
                )
            )
        }

        return entries.sorted { lhs, rhs in
            switch (lhs.latestDetectionDate, rhs.latestDetectionDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }

            if lhs.displayCount != rhs.displayCount {
                return lhs.displayCount > rhs.displayCount
            }

            return lhs.species.commonName.localizedCaseInsensitiveCompare(rhs.species.commonName) == .orderedAscending
        }
    }

    private func detectionSummaries(from detections: [BirdDetection]) -> [String: DetectionSummary] {
        var summaries: [String: DetectionSummary] = [:]

        for detection in detections {
            let key = summaryKey(scientificName: detection.scientificName, commonName: detection.commonName, speciesCode: detection.speciesCode)
            var summary = summaries[key] ?? DetectionSummary(
                key: key,
                commonName: detection.commonName,
                scientificName: detection.scientificName,
                speciesCode: detection.speciesCode
            )

            summary.count += 1
            summary.topConfidence = max(summary.topConfidence ?? detection.confidence, detection.confidence)
            if let timestampDate = detection.timestampDate, summary.latestDetectionDate == nil || timestampDate > summary.latestDetectionDate! {
                summary.latestDetectionDate = timestampDate
            }

            summaries[key] = summary
        }

        return summaries
    }

    private func summaryKey(scientificName: String, commonName: String, speciesCode: String?) -> String {
        (scientificName.nonEmptyString ?? speciesCode?.nonEmptyString ?? commonName)
            .lowercased()
    }

    private func setMessage(_ message: String, kind: StatusKind) {
        statusMessage = message
        statusKind = kind
    }
}

struct SpeciesListEntry: Equatable, Identifiable, Sendable {
    var species: StationSpecies
    var summary: DetectionSummary?

    var id: String { species.id }

    var displayCount: Int {
        species.detectionCount ?? summary?.count ?? 0
    }

    var countLabel: String? {
        guard displayCount > 0 else {
            return nil
        }

        return displayCount == 1 ? String(localized: "1 detection") : String(localized: "\(displayCount) detections")
    }

    var latestDetectionDate: Date? {
        summary?.latestDetectionDate ?? species.latestDetectionTimestamp.flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    var latestDetectionLabel: String? {
        guard let latestDetectionDate else {
            return nil
        }

        return Self.relativeFormatter.localizedString(for: latestDetectionDate, relativeTo: Date())
    }

    var topConfidenceLabel: String? {
        guard let topConfidence = summary?.topConfidence else {
            return nil
        }

        return "\(Int((topConfidence * 100).rounded()))%"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

struct DetectionSummary: Equatable, Sendable {
    var key: String
    var commonName: String
    var scientificName: String
    var speciesCode: String?
    var count = 0
    var latestDetectionDate: Date?
    var topConfidence: Double?
}

private struct SpeciesSnapshot: Codable {
    var catalog: [StationSpecies]
    var detections: [BirdDetection]
}

extension SpeciesViewModel {
    enum StatusKind {
        case neutral
        case warning
        case error

        var systemImage: String {
            switch self {
            case .neutral:
                return "info.circle"
            case .warning:
                return "exclamationmark.triangle"
            case .error:
                return "xmark.octagon"
            }
        }
    }
}

private extension BirdDetection {
    var timestampDate: Date? {
        guard let timestamp else {
            return nil
        }

        return ISO8601DateFormatter().date(from: timestamp)
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
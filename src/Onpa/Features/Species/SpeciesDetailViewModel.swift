import Foundation

@MainActor
final class SpeciesDetailViewModel: ObservableObject {
    @Published private(set) var stationProfile: StationProfile?
    @Published private(set) var detections: [BirdDetection] = []
    @Published private(set) var totalDetections: Int
    @Published private(set) var speciesImageAttribution: SpeciesImageAttribution?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: StatusKind = .neutral
    @Published private(set) var isLoading = false
    @Published private(set) var didLoad = false

    let entry: SpeciesListEntry

    private let detailLimit = 20
    private let fallbackRecentLimit = 200

    init(entry: SpeciesListEntry) {
        self.entry = entry
        self.totalDetections = entry.displayCount
    }

    var species: StationSpecies {
        entry.species
    }

    var audioSamples: [BirdDetection] {
        Array(detections.prefix(3))
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
                detections = []
                setMessage("Connect a BirdNET-Go station to load species details.", kind: .neutral)
                return
            }

            stationProfile = profile
            async let attribution = loadImageAttribution(station: profile, environment: environment)

            do {
                let page = try await environment.apiClient.speciesDetections(station: profile, species: species.commonName, limit: detailLimit)
                detections = page.data
                totalDetections = max(page.total, entry.displayCount)
                statusMessage = detections.isEmpty ? "No recent detections found for this species." : nil
                statusKind = .neutral
            } catch {
                let recent = try await environment.apiClient.recentDetections(station: profile, limit: fallbackRecentLimit)
                detections = recent.filter { $0.matches(species: species) }
                totalDetections = max(entry.displayCount, detections.count)
                if detections.isEmpty {
                    setMessage(error.userFacingMessage, kind: .error)
                } else {
                    setMessage("Showing matching recent detections because species search is unavailable.", kind: .warning)
                }
            }

            speciesImageAttribution = await attribution
        } catch {
            detections = []
            setMessage(error.userFacingMessage, kind: .error)
        }
    }

    func audioURL(for detection: BirdDetection, environment: AppEnvironment) -> URL? {
        guard let stationProfile else {
            return nil
        }

        return environment.apiClient.audioClipURL(station: stationProfile, detectionID: detection.id)
    }

    private func loadStationProfile(environment: AppEnvironment) async throws -> StationProfile? {
        if let overrideURL = environment.configuration.stationURLOverride {
            return StationProfile.manual(baseURL: overrideURL)
        }

        return try await environment.stationProfileStore.loadActiveProfile() ?? environment.configuration.localNetworkTestProfile
    }

    private func loadImageAttribution(station: StationProfile, environment: AppEnvironment) async -> SpeciesImageAttribution? {
        do {
            return try await environment.apiClient.speciesImageAttribution(station: station, scientificName: species.scientificName)
        } catch {
            return nil
        }
    }

    private func setMessage(_ message: String, kind: StatusKind) {
        statusMessage = message
        statusKind = kind
    }
}

extension SpeciesDetailViewModel {
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
    func matches(species: StationSpecies) -> Bool {
        let detectionValues = [speciesCode, scientificName, commonName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let speciesValues = [species.speciesCode, species.scientificName, species.commonName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return !Set(detectionValues).isDisjoint(with: speciesValues)
    }
}
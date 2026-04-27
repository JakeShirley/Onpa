import AVFoundation
import Foundation

@MainActor
final class DetectionDetailViewModel: ObservableObject {
    @Published private(set) var detection: BirdDetection?
    @Published private(set) var stationProfile: StationProfile?
    @Published private(set) var audioURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let detectionID: Int
    private let initialDetection: BirdDetection?

    init(detectionID: Int, initialDetection: BirdDetection? = nil) {
        self.detectionID = detectionID
        self.initialDetection = initialDetection
        self.detection = initialDetection
    }

    func load(environment: AppEnvironment) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let profile = try await loadStationProfile(environment: environment) else {
                stationProfile = nil
                audioURL = nil
                errorMessage = "Connect a BirdNET-Go station to load detection details."
                return
            }

            stationProfile = profile
            audioURL = environment.apiClient.audioClipURL(station: profile, detectionID: detectionID)
            detection = try await environment.apiClient.detection(station: profile, id: detectionID)
            errorMessage = nil
        } catch {
            if detection == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadStationProfile(environment: AppEnvironment) async throws -> StationProfile? {
        if let overrideURL = environment.configuration.stationURLOverride {
            return StationProfile.manual(baseURL: overrideURL)
        }

        return try await environment.stationProfileStore.loadActiveProfile() ?? environment.configuration.localNetworkTestProfile
    }
}

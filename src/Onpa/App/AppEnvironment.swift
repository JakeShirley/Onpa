import SwiftUI

struct AppEnvironment {
    let configuration: AppConfiguration
    let apiClient: any BirdNETGoAPIClient
    let stationProfileStore: any StationProfileStore
    let credentialStore: any StationCredentialStore
    let preferenceStore: any AppPreferenceStore
    let localCacheStore: any LocalCacheStore
    let diagnosticsService: any DiagnosticsService

    static let live = AppEnvironment(
        configuration: .current(),
        apiClient: URLSessionBirdNETGoAPIClient(),
        stationProfileStore: UserDefaultsStationProfileStore(),
        credentialStore: KeychainStationCredentialStore(),
        preferenceStore: UserDefaultsAppPreferenceStore(),
        localCacheStore: FileSystemLocalCacheStore(),
        diagnosticsService: FileDiagnosticsService()
    )

    static let preview = AppEnvironment(
        configuration: .preview,
        apiClient: URLSessionBirdNETGoAPIClient(),
        stationProfileStore: InMemoryStationProfileStore(),
        credentialStore: KeychainStationCredentialStore(),
        preferenceStore: UserDefaultsAppPreferenceStore(key: "preview.preferences", userDefaults: .standard),
        localCacheStore: FileSystemLocalCacheStore(),
        diagnosticsService: FileDiagnosticsService()
    )
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.live
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

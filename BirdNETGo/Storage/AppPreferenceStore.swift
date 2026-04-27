struct AppPreferences: Codable, Equatable, Sendable {
    var rememberStationCredentials: Bool
    var autoFetchSpectrograms: Bool

    static let defaults = AppPreferences(rememberStationCredentials: true, autoFetchSpectrograms: true)

    init(rememberStationCredentials: Bool, autoFetchSpectrograms: Bool) {
        self.rememberStationCredentials = rememberStationCredentials
        self.autoFetchSpectrograms = autoFetchSpectrograms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rememberStationCredentials = try container.decodeIfPresent(Bool.self, forKey: .rememberStationCredentials) ?? Self.defaults.rememberStationCredentials
        autoFetchSpectrograms = try container.decodeIfPresent(Bool.self, forKey: .autoFetchSpectrograms) ?? Self.defaults.autoFetchSpectrograms
    }
}

protocol AppPreferenceStore: Sendable {
    func loadPreferences() async throws -> AppPreferences
    func savePreferences(_ preferences: AppPreferences) async throws
}

import Combine
import Foundation

@MainActor
final class StationViewModel: ObservableObject {
    @Published var baseURLText = ""
    @Published var username = ""
    @Published var password = ""
    @Published var rememberCredentials = true
    @Published private(set) var connectionReport: StationConnectionReport?
    @Published private(set) var authStatus: StationAuthStatus?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: StatusKind = .neutral
    @Published private(set) var diagnosticsBundleURL: URL?
    @Published private(set) var isBusy = false
    @Published private(set) var activeProfile: StationProfile?
    @Published private(set) var canDeleteStation = false

    private var didLoad = false

    var canLogIn: Bool {
        connectionReport?.appConfig.security.authConfig.basicEnabled == true
    }

    var canLogOut: Bool {
        authStatus?.authenticated == true
    }

    func load(environment: AppEnvironment) async {
        guard !didLoad else {
            return
        }

        didLoad = true

        do {
            let preferences = try await environment.preferenceStore.loadPreferences()
            rememberCredentials = preferences.rememberStationCredentials

            let storedProfile = try await environment.stationProfileStore.loadActiveProfile()
            let overrideProfile = environment.configuration.stationURLOverride.map(StationProfile.manual(baseURL:))
            guard let profile = overrideProfile ?? storedProfile ?? environment.configuration.localNetworkTestProfile else {
                return
            }

            activeProfile = profile
            canDeleteStation = overrideProfile == nil && storedProfile != nil
            baseURLText = profile.baseURL.absoluteString
            if let credentials = try await environment.credentialStore.loadCredentials(for: profile) {
                username = credentials.username ?? ""
                password = credentials.password
            }

            if environment.configuration.stationURLOverride != nil {
                setMessage("Using debug station URL override.", kind: .neutral)
            } else if storedProfile == nil, environment.configuration.localNetworkTestProfile != nil {
                setMessage("Loaded local test station profile.", kind: .neutral)
            }
        } catch {
            setMessage(error.userFacingMessage, kind: .warning)
        }
    }

    func connect(environment: AppEnvironment) async {
        await performBusyOperation {
            let baseURL = try StationURLValidator.normalizedURL(from: baseURLText)
            guard StationURLValidator.tlsState(for: baseURL) != .insecurePlainHTTP else {
                throw StationConnectionError.insecurePlainHTTP
            }

            let profile = StationProfile.manual(baseURL: baseURL)
            let report = try await environment.apiClient.validateConnection(station: profile)
            try await environment.stationProfileStore.saveActiveProfile(profile)

            activeProfile = profile
            canDeleteStation = true
            connectionReport = report
            authStatus = nil
            baseURLText = baseURL.absoluteString

            if let credentials = try await environment.credentialStore.loadCredentials(for: profile) {
                username = credentials.username ?? ""
                password = credentials.password
            }

            let message = report.requiresAuthentication ? "Station connected. Login required." : "Station connected."
            setMessage(message, kind: .success)
        }
    }

    func deleteStation(environment: AppEnvironment) async {
        await performBusyOperation {
            let profile = try await currentProfile(environment: environment)

            try await environment.credentialStore.deleteCredentials(for: profile)
            try await environment.stationProfileStore.saveActiveProfile(nil)

            activeProfile = nil
            canDeleteStation = false
            connectionReport = nil
            authStatus = nil
            diagnosticsBundleURL = nil
            baseURLText = ""
            username = ""
            password = ""

            setMessage("Station deleted.", kind: .success)
        }
    }

    func logIn(environment: AppEnvironment) async {
        await performBusyOperation {
            let report = try await ensureConnected(environment: environment)
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let credentials = StationCredentials(username: trimmedUsername.isEmpty ? nil : trimmedUsername, password: password)
            guard !credentials.password.isEmpty else {
                throw StationConnectionError.serverRejected(statusCode: 400, message: "Password is required.")
            }

            let response = try await environment.apiClient.login(station: report.profile, credentials: credentials, csrfToken: report.appConfig.csrfToken)
            let status = try await environment.apiClient.authStatus(station: report.profile)
            authStatus = status
            try await saveCurrentPreferences(environment: environment)

            if response.success && rememberCredentials {
                try await environment.credentialStore.saveCredentials(credentials, for: report.profile)
            }

            setMessage(status.authenticated ? "Logged in." : response.message, kind: response.success ? .success : .warning)
        }
    }

    func logOut(environment: AppEnvironment) async {
        await performBusyOperation {
            let report = try await ensureConnected(environment: environment)
            _ = try await environment.apiClient.logout(station: report.profile, csrfToken: report.appConfig.csrfToken)
            try await environment.credentialStore.deleteCredentials(for: report.profile)
            password = ""
            authStatus = StationAuthStatus(authenticated: false, username: nil, method: nil)
            setMessage("Logged out.", kind: .success)
        }
    }

    func savePreferences(environment: AppEnvironment) async {
        do {
            try await saveCurrentPreferences(environment: environment)
        } catch {
            setMessage(error.userFacingMessage, kind: .warning)
        }
    }

    func generateDiagnostics(environment: AppEnvironment) async {
        await performBusyOperation {
            let preferences = try? await environment.preferenceStore.loadPreferences()
            let activeProfile = try? await environment.stationProfileStore.loadActiveProfile()
            diagnosticsBundleURL = try await environment.diagnosticsService.makeDiagnosticsBundle(
                snapshot: DiagnosticsSnapshot(
                    configuration: environment.configuration,
                    activeProfile: activeProfile,
                    preferences: preferences,
                    connectionReport: connectionReport,
                    authStatus: authStatus,
                    statusMessage: statusMessage
                )
            )
            setMessage("Diagnostics bundle ready to share.", kind: .success)
        }
    }

    func refreshAuthStatus(environment: AppEnvironment) async {
        await performBusyOperation {
            let report = try await ensureConnected(environment: environment)
            authStatus = try await environment.apiClient.authStatus(station: report.profile)
            setMessage(authStatus?.authenticated == true ? "Authenticated." : "Not authenticated.", kind: .neutral)
        }
    }

    private func ensureConnected(environment: AppEnvironment) async throws -> StationConnectionReport {
        if let connectionReport {
            return connectionReport
        }

        let baseURL = try StationURLValidator.normalizedURL(from: baseURLText)
        guard StationURLValidator.tlsState(for: baseURL) != .insecurePlainHTTP else {
            throw StationConnectionError.insecurePlainHTTP
        }

        let profile = StationProfile.manual(baseURL: baseURL)
        let report = try await environment.apiClient.validateConnection(station: profile)
        try await environment.stationProfileStore.saveActiveProfile(profile)
        activeProfile = profile
        canDeleteStation = true
        connectionReport = report
        baseURLText = baseURL.absoluteString
        return report
    }

    private func currentProfile(environment: AppEnvironment) async throws -> StationProfile {
        guard canDeleteStation else {
            throw StationConnectionError.invalidURL
        }

        if let activeProfile {
            return activeProfile
        }

        if let storedProfile = try await environment.stationProfileStore.loadActiveProfile() {
            return storedProfile
        }

        throw StationConnectionError.invalidURL
    }

    private func performBusyOperation(_ operation: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            setMessage(error.userFacingMessage, kind: .error)
        }
    }

    private func setMessage(_ message: String, kind: StatusKind) {
        statusMessage = message
        statusKind = kind
    }

    private func saveCurrentPreferences(environment: AppEnvironment) async throws {
        var preferences = try await environment.preferenceStore.loadPreferences()
        preferences.rememberStationCredentials = rememberCredentials
        try await environment.preferenceStore.savePreferences(
            preferences
        )
    }
}

extension StationViewModel {
    enum StatusKind {
        case neutral
        case success
        case warning
        case error

        var systemImage: String {
            switch self {
            case .neutral:
                return "info.circle"
            case .success:
                return "checkmark.circle"
            case .warning:
                return "exclamationmark.triangle"
            case .error:
                return "xmark.octagon"
            }
        }
    }
}
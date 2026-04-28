import Foundation

struct DiagnosticsSnapshot: Sendable {
    var configuration: AppConfiguration
    var activeProfile: StationProfile?
    var preferences: AppPreferences?
    var connectionReport: StationConnectionReport?
    var authStatus: StationAuthStatus?
    var statusMessage: String?
}

protocol DiagnosticsService: Sendable {
    func makeDiagnosticsBundle(snapshot: DiagnosticsSnapshot) async throws -> URL
}

actor FileDiagnosticsService: DiagnosticsService {
    private let rootDirectory: URL

    init(rootDirectory: URL = FileDiagnosticsService.defaultRootDirectory()) {
        self.rootDirectory = rootDirectory
    }

    func makeDiagnosticsBundle(snapshot: DiagnosticsSnapshot) async throws -> URL {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let generatedAt = Date()
        let timestamp = ISO8601DateFormatter().string(from: generatedAt).replacingOccurrences(of: ":", with: "-")
        let fileURL = rootDirectory.appending(path: "onpa-ios-diagnostics-\(timestamp).txt", directoryHint: .notDirectory)
        try diagnosticsText(snapshot: snapshot, generatedAt: generatedAt).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func diagnosticsText(snapshot: DiagnosticsSnapshot, generatedAt: Date) -> String {
        var lines: [String] = []
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

        lines.append("Onpa iOS Diagnostics")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: generatedAt))")
        lines.append("App Version: \(appVersion) (\(build))")
        lines.append("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("")

        lines.append("Configuration")
        lines.append("Station URL Override: \(redactedURL(snapshot.configuration.stationURLOverride))")
        lines.append("Local Test Profile: \(redactedURL(snapshot.configuration.localNetworkTestProfile?.baseURL))")
        lines.append("Debug Detection ID: \(snapshot.configuration.debugDetectionID.map(String.init) ?? "none")")
        lines.append("")

        lines.append("Station")
        lines.append("Active Profile URL: \(redactedURL(snapshot.activeProfile?.baseURL))")
        lines.append("Connected Profile URL: \(redactedURL(snapshot.connectionReport?.profile.baseURL))")
        lines.append("Connection Status: \(snapshot.connectionReport?.status.displayName ?? "unknown")")
        lines.append("TLS State: \(snapshot.connectionReport?.tlsState.displayName ?? "unknown")")
        lines.append("BirdNET-Go Identity: \(snapshot.connectionReport?.identity ?? "unknown")")
        lines.append("Security Enabled: \(snapshot.connectionReport?.appConfig.security.enabled.yesNo ?? "unknown")")
        lines.append("Access Allowed: \(snapshot.connectionReport?.appConfig.security.accessAllowed.yesNo ?? "unknown")")
        lines.append("Direct Login Advertised: \(snapshot.connectionReport?.appConfig.security.authConfig.basicEnabled.yesNo ?? "unknown")")
        lines.append("")

        lines.append("Account")
        lines.append("Authenticated: \(snapshot.authStatus?.authenticated.yesNo ?? "unknown")")
        lines.append("Auth Method: \(snapshot.authStatus?.method?.redactedIfPresent ?? "none")")
        lines.append("Username Present: \((snapshot.authStatus?.username?.isEmpty == false).yesNo)")
        lines.append("")

        lines.append("Preferences")
        lines.append("Remember Credentials: \(snapshot.preferences?.rememberStationCredentials.yesNo ?? "unknown")")
        lines.append("Auto Fetch Spectrograms: \(snapshot.preferences?.autoFetchSpectrograms.yesNo ?? "unknown")")
        lines.append("")

        lines.append("Last Status")
        lines.append(snapshot.statusMessage?.redactingLikelySecrets ?? "none")

        return lines.joined(separator: "\n") + "\n"
    }

    private func redactedURL(_ url: URL?) -> String {
        guard let url else {
            return "none"
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.user = nil
        components?.password = nil
        components?.host = url.host(percentEncoded: false).map { _ in "redacted-station" }
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? "redacted-url"
    }

    private static func defaultRootDirectory() -> URL {
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cachesURL.appending(path: "Onpa/Diagnostics", directoryHint: .isDirectory)
        }

        return FileManager.default.temporaryDirectory.appending(path: "Onpa/Diagnostics", directoryHint: .isDirectory)
    }
}

private extension Bool {
    var yesNo: String {
        self ? "yes" : "no"
    }
}

private extension String {
    var redactedIfPresent: String {
        isEmpty ? "none" : "redacted"
    }

    var redactingLikelySecrets: String {
        let patterns = ["password", "token", "secret", "cookie", "authorization"]
        return patterns.contains { range(of: $0, options: .caseInsensitive) != nil } ? "redacted" : self
    }
}
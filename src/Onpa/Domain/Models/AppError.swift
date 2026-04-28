import Foundation

enum AppError: LocalizedError, Equatable, Sendable {
    case offline
    case authenticationRequired
    case permissionDenied
    case tlsFailure
    case rateLimited
    case server(statusCode: Int, message: String?)
    case invalidStationResponse
    case invalidStationURL
    case insecurePlainHTTP
    case unknown(message: String)

    init(_ error: Error) {
        if let appError = error as? AppError {
            self = appError
            return
        }

        if let connectionError = error as? StationConnectionError {
            self = Self(connectionError)
            return
        }

        if let urlError = error as? URLError {
            self = Self(urlError)
            return
        }

        self = .unknown(message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .offline:
            return String(localized: "The station appears to be offline or unreachable.")
        case .authenticationRequired:
            return String(localized: "Log in to the station to continue.")
        case .permissionDenied:
            return String(localized: "The station denied this request. Check your account permissions.")
        case .tlsFailure:
            return String(localized: "The station's secure connection could not be trusted.")
        case .rateLimited:
            return String(localized: "The station is receiving too many requests. Try again in a moment.")
        case let .server(statusCode, message):
            if let message {
                return message
            }
            return String(localized: "The station returned HTTP \(statusCode).")
        case .invalidStationResponse:
            return String(localized: "The station returned an unexpected response.")
        case .invalidStationURL:
            return String(localized: "Enter a valid BirdNET-Go station URL.")
        case .insecurePlainHTTP:
            return String(localized: "Use HTTPS for remote stations. Plain HTTP is only supported for localhost, private IPs, and .local stations.")
        case let .unknown(message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline:
            return String(localized: "Confirm the station is running and reachable from this device.")
        case .authenticationRequired:
            return String(localized: "Open the Dashboard station menu and log in with your BirdNET-Go password.")
        case .permissionDenied:
            return String(localized: "Log out and back in, or check the station's security settings.")
        case .tlsFailure:
            return String(localized: "Use a valid HTTPS certificate, or connect over local HTTP for trusted local stations.")
        case .rateLimited:
            return String(localized: "Wait briefly before refreshing or reconnecting.")
        case .server, .invalidStationResponse:
            return String(localized: "Check the station logs or generate a diagnostics bundle from the Dashboard station menu.")
        case .invalidStationURL:
            return String(localized: "Include the scheme and host, for example http://birdnet.local:8080.")
        case .insecurePlainHTTP:
            return String(localized: "Use HTTPS for remote hosts, or connect to a localhost, private IP, or .local address.")
        case .unknown:
            return nil
        }
    }

    private init(_ connectionError: StationConnectionError) {
        switch connectionError {
        case .invalidURL, .unsupportedScheme, .missingHost:
            self = .invalidStationURL
        case .invalidResponse, .missingBirdNETGoConfig:
            self = .invalidStationResponse
        case .insecurePlainHTTP:
            self = .insecurePlainHTTP
        case let .serverRejected(statusCode, message):
            switch statusCode {
            case 0:
                self = .offline
            case 401:
                self = .authenticationRequired
            case 403:
                self = .permissionDenied
            case 429:
                self = .rateLimited
            default:
                self = .server(statusCode: statusCode, message: message)
            }
        }
    }

    private init(_ urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .timedOut:
            self = .offline
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection:
            self = .tlsFailure
        default:
            self = .unknown(message: urlError.localizedDescription)
        }
    }
}

extension Error {
    var userFacingMessage: String {
        AppError(self).errorDescription ?? localizedDescription
    }
}
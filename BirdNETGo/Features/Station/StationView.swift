import SwiftUI

struct StationView: View {
    var body: some View {
        Form {
            Section("Connection") {
                LabeledContent("Station", value: "Not connected")
                LabeledContent("Status", value: "Offline")
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Station")
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        case (nil, nil):
            return "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        StationView()
    }
}

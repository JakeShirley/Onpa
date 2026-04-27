import SwiftUI

struct DetectionDetailView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel: DetectionDetailViewModel

    init(detectionID: Int, initialDetection: BirdDetection? = nil) {
        _viewModel = StateObject(wrappedValue: DetectionDetailViewModel(detectionID: detectionID, initialDetection: initialDetection))
    }

    var body: some View {
        List {
            if viewModel.isLoading, viewModel.detection == nil {
                ProgressView("Loading detection")
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowBackground(Color.clear)
            } else if let detection = viewModel.detection {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(detection.commonName)
                            .font(.title2.weight(.semibold))
                        Text(detection.scientificName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Label("\(detection.confidencePercent)%", systemImage: "checkmark.seal")
                            Label(detection.timeLabel, systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Audio") {
                    AudioClipPlayerView(audioURL: viewModel.audioURL, title: detection.commonName)
                }

                Section("Details") {
                    DetailRow(title: "Date", value: detection.date)
                    DetailRow(title: "Time", value: detection.time)
                    if let sourceLabel = detection.sourceLabel {
                        DetailRow(title: "Source", value: sourceLabel)
                    }
                    if let speciesCode = detection.speciesCode {
                        DetailRow(title: "Species Code", value: speciesCode)
                    }
                    if let clipName = detection.clipName, !clipName.isEmpty {
                        DetailRow(title: "Clip", value: clipName)
                    }
                    if let interval = detection.recordedIntervalLabel {
                        DetailRow(title: "Recording", value: interval)
                    }
                    DetailRow(title: "Review", value: detection.verified ?? "Unverified")
                    if detection.locked {
                        Label("Locked", systemImage: "lock.fill")
                    }
                    if detection.isNewSpecies == true {
                        Label("New species", systemImage: "sparkle")
                    }
                }
            } else {
                ContentUnavailableView(
                    viewModel.errorMessage ?? "Detection Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Try again from the Feed tab.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Detection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.load(environment: appEnvironment)
        }
        .refreshable {
            await viewModel.load(environment: appEnvironment)
        }
    }
}

private struct DetailRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        DetectionDetailView(detectionID: 1)
    }
    .environment(\.appEnvironment, .preview)
}

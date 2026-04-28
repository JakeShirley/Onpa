import AVFoundation
import SwiftUI

struct AudioClipPlayerView: View {
    var audioURL: URL?
    var title: String

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .disabled(audioURL == nil)
                .accessibilityLabel(isPlaying ? "Pause audio clip" : "Play audio clip")

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(statusMessage ?? "Detection audio clip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear(perform: preparePlayer)
        .onChange(of: audioURL) { _, _ in
            preparePlayer()
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    private func preparePlayer() {
        player?.pause()
        isPlaying = false

        guard let audioURL else {
            player = nil
            statusMessage = String(localized: "No audio clip URL available.")
            return
        }

        player = AVPlayer(url: audioURL)
        statusMessage = String(localized: "Ready to play")
    }

    private func togglePlayback() {
        guard let player else {
            return
        }

        if isPlaying {
            player.pause()
            statusMessage = String(localized: "Paused")
        } else {
            player.play()
            statusMessage = String(localized: "Playing")
        }

        isPlaying.toggle()
    }
}

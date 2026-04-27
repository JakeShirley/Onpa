import SwiftUI

struct FeedView: View {
    var body: some View {
        List {
            ContentUnavailableView(
                "No Station Connected",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Connect a BirdNET-Go station from the Station tab to see recent detections.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(true)
                .accessibilityLabel("Refresh feed")
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedView()
    }
}

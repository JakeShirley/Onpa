import SwiftUI

struct StatsView: View {
    var body: some View {
        List {
            ContentUnavailableView(
                "No Stats Available",
                systemImage: "chart.bar",
                description: Text("Station activity summaries will appear here after detections load.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Stats")
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
}

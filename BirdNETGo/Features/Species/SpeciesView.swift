import SwiftUI

struct SpeciesView: View {
    var body: some View {
        List {
            ContentUnavailableView(
                "No Species Yet",
                systemImage: "leaf",
                description: Text("Detected species will appear here after a station is connected.")
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Species")
    }
}

#Preview {
    NavigationStack {
        SpeciesView()
    }
}

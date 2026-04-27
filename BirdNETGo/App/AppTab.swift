import SwiftUI

enum AppTab: Hashable, CaseIterable, Identifiable {
    case feed
    case species
    case stats
    case station

    var id: Self { self }

    var title: String {
        switch self {
        case .feed:
            "Feed"
        case .species:
            "Species"
        case .stats:
            "Stats"
        case .station:
            "Station"
        }
    }

    var systemImage: String {
        switch self {
        case .feed:
            "list.bullet"
        case .species:
            "leaf"
        case .stats:
            "chart.bar"
        case .station:
            "antenna.radiowaves.left.and.right"
        }
    }
}

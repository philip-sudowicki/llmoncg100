import Foundation

/// A place's personal status for the user right now. A closed place has no status (`nil`).
enum TideStatus: Int, CaseIterable, Comparable, Sendable, Identifiable {
    case calm
    case busy
    case high

    var id: Int { rawValue }

    static func < (lhs: TideStatus, rhs: TideStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .busy: "Busy"
        case .high: "High tide"
        }
    }

    /// Number of waves in the status glyph, so status never relies on colour alone.
    var waveCount: Int {
        switch self {
        case .calm: 1
        case .busy: 2
        case .high: 3
        }
    }
}

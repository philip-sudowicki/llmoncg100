import Foundation

/// A sensory factor that Lowtide forecasts for every place.
enum Factor: String, CaseIterable, Codable, Sendable, Identifiable {
    case noise
    case sudden
    case light
    case crowd
    case smell

    var id: String { rawValue }

    /// The row title in the Tide profile ("What gets to you").
    var profileTitle: String {
        switch self {
        case .noise: "Loud noise"
        case .sudden: "Sudden sounds"
        case .light: "Bright or flickering light"
        case .crowd: "Crowds"
        case .smell: "Strong smells"
        }
    }
}

/// How strongly a factor affects the user. Each level scales that factor's forecast.
enum Sensitivity: String, CaseIterable, Codable, Sendable, Identifiable {
    case aBit
    case some
    case aLot

    var id: String { rawValue }

    var weight: Double {
        switch self {
        case .aBit: 0.5
        case .some: 1.0
        case .aLot: 1.6
        }
    }

    var title: String {
        switch self {
        case .aBit: "A bit"
        case .some: "Some"
        case .aLot: "A lot"
        }
    }

    /// Heads-up chips appear for triggers whose factor is set to Some or A lot.
    var wantsHeadsUps: Bool { self != .aBit }
}

/// Things that help the user feel settled. Stored now so places can be ranked by them later.
enum Help: String, CaseIterable, Codable, Sendable, Identifiable {
    case naturalLight
    case cornerSeat
    case outdoorSpace
    case quietRoom
    case fewerPeople
    case softMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naturalLight: "Natural light"
        case .cornerSeat: "Corner seat"
        case .outdoorSpace: "Outdoor space"
        case .quietRoom: "Quiet room"
        case .fewerPeople: "Fewer people"
        case .softMusic: "Soft music"
        }
    }
}

import Foundation

/// The five sensory factors Lowtide forecasts for every place.
///
/// Forecast values are normalised from 0 (not noticeable) to 1 (as intense as it gets).
enum Factor: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case noise
    case sudden
    case light
    case crowd
    case smell

    var id: String { rawValue }

    /// The label used in the Tide profile ("What gets to you").
    var profileLabel: String {
        switch self {
        case .noise: "Loud noise"
        case .sudden: "Sudden sounds"
        case .light: "Bright or flickering light"
        case .crowd: "Crowds"
        case .smell: "Strong smells"
        }
    }
}

/// How strongly one factor affects someone.
///
/// The cases avoid the names `some` and `none` so they never collide with `Optional`.
enum Sensitivity: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// "A bit"
    case mild
    /// "Some"
    case moderate
    /// "A lot"
    case strong

    var id: String { rawValue }

    /// The multiplier applied to a factor's forecast value.
    var weight: Double {
        switch self {
        case .mild: 0.5
        case .moderate: 1.0
        case .strong: 1.6
        }
    }

    var label: String {
        switch self {
        case .mild: "A bit"
        case .moderate: "Some"
        case .strong: "A lot"
        }
    }

    /// Triggers tied to a factor get a heads-up chip at Some or A lot.
    var wantsHeadsUp: Bool { self != .mild }
}

/// Things that help someone feel calm. Stored now so places can be ranked by them later.
enum Help: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case naturalLight
    case cornerSeat
    case outdoorSpace
    case quietRoom
    case fewerPeople
    case softMusic

    var id: String { rawValue }

    var label: String {
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

/// Everything the user has told Lowtide about themselves. It never leaves the device.
struct SensoryProfile: Equatable, Sendable {
    var noise: Sensitivity = .moderate
    var sudden: Sensitivity = .moderate
    var light: Sensitivity = .moderate
    var crowd: Sensitivity = .moderate
    var smell: Sensitivity = .moderate
    var helps: Set<Help> = []
    /// Master switch for "Alert me". Off until the user turns it on.
    var gentleAlerts = false
    var shareSoundReadings = true
    var trustedPerson = ""

    static let standard = SensoryProfile()

    subscript(sensitivity factor: Factor) -> Sensitivity {
        get {
            switch factor {
            case .noise: noise
            case .sudden: sudden
            case .light: light
            case .crowd: crowd
            case .smell: smell
            }
        }
        set {
            switch factor {
            case .noise: noise = newValue
            case .sudden: sudden = newValue
            case .light: light = newValue
            case .crowd: crowd = newValue
            case .smell: smell = newValue
            }
        }
    }

    func weight(for factor: Factor) -> Double {
        self[sensitivity: factor].weight
    }

    /// The trusted person's name, or `nil` when the field is blank.
    var trustedPersonName: String? {
        let name = trustedPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

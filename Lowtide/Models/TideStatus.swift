import Foundation

/// How a place feels for one person at one moment.
enum TideStatus: String, CaseIterable, Codable, Hashable, Sendable {
    /// Low tide: below 0.4.
    case calm
    /// Below 0.7.
    case busy
    /// 0.7 or above.
    case high

    init(score: Double) {
        if score < TideEngine.calmThreshold {
            self = .calm
        } else if score < TideEngine.highThreshold {
            self = .busy
        } else {
            self = .high
        }
    }

    /// The number of waves in the status glyph, so status never relies on colour alone.
    var waveCount: Int {
        switch self {
        case .calm: 1
        case .busy: 2
        case .high: 3
        }
    }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .busy: "Busy"
        case .high: "High tide"
        }
    }
}

/// How someone felt when they checked in.
enum CheckInFeeling: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case calm
    case okay
    case tooMuch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .okay: "Okay"
        case .tooMuch: "Too much"
        }
    }

    /// The status whose glyph and colour represent this feeling.
    var status: TideStatus {
        switch self {
        case .calm: .calm
        case .okay: .busy
        case .tooMuch: .high
        }
    }
}

/// What someone noticed during a check-in.
enum NoticedTrigger: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case music
    case chatter
    case handDryer
    case coffeeMachine
    case brightLights
    case flicker
    case crowds
    case smells
    case suddenNoises

    var id: String { rawValue }

    var label: String {
        switch self {
        case .music: "Music"
        case .chatter: "Chatter"
        case .handDryer: "Hand dryer"
        case .coffeeMachine: "Coffee machine"
        case .brightLights: "Bright lights"
        case .flicker: "Flicker"
        case .crowds: "Crowds"
        case .smells: "Smells"
        case .suddenNoises: "Sudden noises"
        }
    }
}

import Foundation

/// How a place felt at check-in.
enum CheckInFeeling: String, CaseIterable, Sendable, Identifiable {
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

    /// The matching tide status, which supplies the glyph and colour.
    var status: TideStatus {
        switch self {
        case .calm: .calm
        case .okay: .busy
        case .tooMuch: .high
        }
    }
}

/// "What did you notice?" options at check-in.
enum NoticedThing: String, CaseIterable, Sendable, Identifiable {
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

    var title: String {
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

import Foundation

/// Something at a place that can catch someone out. Each tag belongs to one factor.
enum TriggerTag: String, CaseIterable, Codable, Sendable {
    case handDryer
    case bell
    case coffeeGrinder
    case milkSteamer
    case announcements
    case trainBrakes
    case dogs
    case doorBuzzer
    case music
    case chatter
    case children
    case traffic
    case stripLights
    case flicker
    case glare
    case crowdSurge
    case queues
    case perfume
    case cooking
    case cleaningProducts

    var factor: Factor {
        switch self {
        case .handDryer, .bell, .coffeeGrinder, .milkSteamer, .announcements, .trainBrakes, .dogs, .doorBuzzer:
            .sudden
        case .music, .chatter, .children, .traffic:
            .noise
        case .stripLights, .flicker, .glare:
            .light
        case .crowdSurge, .queues:
            .crowd
        case .perfume, .cooking, .cleaningProducts:
            .smell
        }
    }

    /// Fallback chip text when a place gives no label of its own.
    var defaultLabel: String {
        switch self {
        case .handDryer: "Hand dryer"
        case .bell: "Bell"
        case .coffeeGrinder: "Coffee grinder"
        case .milkSteamer: "Milk steamer"
        case .announcements: "Announcements"
        case .trainBrakes: "Train brakes"
        case .dogs: "Dogs"
        case .doorBuzzer: "Door buzzer"
        case .music: "Music"
        case .chatter: "Chatter"
        case .children: "Children playing"
        case .traffic: "Traffic"
        case .stripLights: "Strip lights"
        case .flicker: "Flickering lights"
        case .glare: "Glare"
        case .crowdSurge: "Sudden crowds"
        case .queues: "Queues"
        case .perfume: "Perfume"
        case .cooking: "Cooking smells"
        case .cleaningProducts: "Cleaning products"
        }
    }
}

/// A trigger at a specific place, for example "Closing bell at 6:45pm".
struct PlaceTrigger: Hashable, Sendable, Decodable {
    let tag: TriggerTag
    let label: String

    init(tag: TriggerTag, label: String? = nil) {
        self.tag = tag
        self.label = label ?? tag.defaultLabel
    }

    private enum CodingKeys: String, CodingKey { case tag, label }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(TriggerTag.self, forKey: .tag)
        self.init(tag: tag, label: try container.decodeIfPresent(String.self, forKey: .label))
    }
}

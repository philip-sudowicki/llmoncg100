import Foundation

/// A calm (or not so calm) place on the map.
struct Place: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: PlaceCategory
    let street: String
    /// Position relative to the demo centre, so the sample data works wherever the user is.
    let offset: MetreOffset
    let hours: OpeningHours
    let forecast: HourlyForecast
    let triggers: [Trigger]
    let goodToKnow: [GoodToKnow]
    let quietHour: QuietHour?
    let busyPeriods: [BusyPeriod]
    let notes: FeelNotes

    func position(around anchor: GeoPoint) -> GeoPoint {
        anchor.offsetBy(east: offset.east, north: offset.north)
    }
}

enum PlaceCategory: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case library
    case cafe
    case park
    case market
    case station
    case bookshop
    case quietRoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "Library"
        case .cafe: "Café"
        case .park: "Park"
        case .market: "Market"
        case .station: "Station"
        case .bookshop: "Bookshop"
        case .quietRoom: "Quiet room"
        }
    }

    /// SF Symbol for icon tiles.
    var symbol: String {
        switch self {
        case .library: "book.closed"
        case .cafe: "cup.and.saucer"
        case .park: "leaf"
        case .market: "basket"
        case .station: "tram"
        case .bookshop: "books.vertical"
        case .quietRoom: "sofa"
        }
    }
}

/// Opening hours as minutes after midnight. The same hours apply every day in v1.
struct OpeningHours: Hashable, Sendable {
    let open: Int
    /// Exclusive. 1440 means midnight at the end of the day.
    let close: Int

    func isOpen(atMinute minute: Int) -> Bool {
        minute >= open && minute < close
    }
}

struct MetreOffset: Codable, Hashable, Sendable {
    let east: Double
    let north: Double
}

/// Something at a place that might catch a sensitive person off guard.
struct Trigger: Codable, Hashable, Sendable, Identifiable {
    let tag: TriggerTag
    /// Place-specific wording, such as "Closing bell at 6:45pm".
    let label: String?

    var id: String { tag.rawValue + (label ?? "") }
    var text: String { label ?? tag.defaultLabel }
    var factor: Factor { tag.factor }
}

enum TriggerTag: String, Codable, CaseIterable, Hashable, Sendable {
    case handDryer
    case music
    case coffeeGrinder
    case stripLights
    case flicker
    case bell
    case perfume
    case foodSmells
    case announcements
    case trains
    case chatter
    case children
    case dogs
    case crowding
    case cleaningProducts
    case brightScreens

    /// The factor a trigger belongs to, which decides whether it earns a heads-up.
    var factor: Factor {
        switch self {
        case .handDryer, .coffeeGrinder, .bell, .announcements, .trains, .dogs: .sudden
        case .music, .chatter, .children: .noise
        case .stripLights, .flicker, .brightScreens: .light
        case .perfume, .foodSmells, .cleaningProducts: .smell
        case .crowding: .crowd
        }
    }

    var defaultLabel: String {
        switch self {
        case .handDryer: "Hand dryer"
        case .music: "Background music"
        case .coffeeGrinder: "Coffee grinder"
        case .stripLights: "Strip lights"
        case .flicker: "Flickering lights"
        case .bell: "Bell"
        case .perfume: "Perfume"
        case .foodSmells: "Food smells"
        case .announcements: "Announcements"
        case .trains: "Train brakes"
        case .chatter: "Chatter"
        case .children: "Children playing"
        case .dogs: "Dogs barking"
        case .crowding: "Queues and crowding"
        case .cleaningProducts: "Cleaning products"
        case .brightScreens: "Bright screens"
        }
    }
}

/// A practical note shown in "Good to know".
struct GoodToKnow: Hashable, Sendable, Identifiable {
    let kind: Kind
    let text: String

    var id: String { text }

    enum Kind: String, Codable, Hashable, Sendable {
        case quietSpace
        case quietHour
        case staff
        case stepFree
        case seating
        case toilets
        case outdoors
        case lighting
        case kit
        case info
    }
}

/// A regular quieter hour, such as "weekdays, 9–10am".
struct QuietHour: Hashable, Sendable {
    let days: String
    let start: Int
    let end: Int
}

/// A predictable rush, used to explain changes ("then the after-school rush").
struct BusyPeriod: Hashable, Sendable {
    let start: Int
    let end: Int
    let label: String
}

/// Optional place-specific wording for the "How it feels" rows.
struct FeelNotes: Codable, Hashable, Sendable {
    var noise: String?
    var light: String?
    var crowd: String?
    var smell: String?

    init(noise: String? = nil, light: String? = nil, crowd: String? = nil, smell: String? = nil) {
        self.noise = noise
        self.light = light
        self.crowd = crowd
        self.smell = smell
    }
}

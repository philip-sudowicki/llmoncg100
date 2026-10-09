import Foundation

/// A place on the map with its daily sensory forecast. Decoded from `places.json`.
struct Place: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let name: String
    let category: PlaceCategory
    let street: String
    /// Position in metres from the demo centre, so the sample data works wherever the user is.
    let offset: MetreOffset
    let hours: OpeningHours
    let forecast: Forecast
    /// Named busy spells, used for text such as "then the after-school rush".
    let periods: [NamedPeriod]
    let triggers: [PlaceTrigger]
    let notes: FactorNotes
    let goodToKnow: [GoodToKnow]
    let quietHour: QuietHour?

    init(
        id: String,
        name: String,
        category: PlaceCategory,
        street: String,
        offset: MetreOffset,
        hours: OpeningHours,
        forecast: Forecast,
        periods: [NamedPeriod] = [],
        triggers: [PlaceTrigger] = [],
        notes: FactorNotes = FactorNotes(),
        goodToKnow: [GoodToKnow] = [],
        quietHour: QuietHour? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.street = street
        self.offset = offset
        self.hours = hours
        self.forecast = forecast
        self.periods = periods
        self.triggers = triggers
        self.notes = notes
        self.goodToKnow = goodToKnow
        self.quietHour = quietHour
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, street, offset, hours, forecast, periods, triggers, notes, goodToKnow, quietHour
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(PlaceCategory.self, forKey: .category)
        street = try container.decode(String.self, forKey: .street)
        offset = try container.decode(MetreOffset.self, forKey: .offset)
        hours = try container.decode(OpeningHours.self, forKey: .hours)
        forecast = try container.decode(Forecast.self, forKey: .forecast)
        periods = try container.decodeIfPresent([NamedPeriod].self, forKey: .periods) ?? []
        triggers = try container.decodeIfPresent([PlaceTrigger].self, forKey: .triggers) ?? []
        notes = try container.decodeIfPresent(FactorNotes.self, forKey: .notes) ?? FactorNotes()
        goodToKnow = try container.decodeIfPresent([GoodToKnow].self, forKey: .goodToKnow) ?? []
        quietHour = try container.decodeIfPresent(QuietHour.self, forKey: .quietHour)
    }

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PlaceCategory: String, CaseIterable, Codable, Sendable {
    case library
    case cafe
    case park
    case market
    case station
    case bookshop
    case quietRoom

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
    var symbolName: String {
        switch self {
        case .library: "books.vertical"
        case .cafe: "cup.and.saucer"
        case .park: "leaf"
        case .market: "basket"
        case .station: "tram"
        case .bookshop: "book.closed"
        case .quietRoom: "sofa"
        }
    }
}

/// Metres east and north of the demo centre.
struct MetreOffset: Codable, Hashable, Sendable {
    let east: Double
    let north: Double
}

/// Daily opening hours as minutes since midnight. The same hours apply every day in v1.
struct OpeningHours: Hashable, Sendable, Decodable {
    let opens: Int
    let closes: Int

    init(opens: Int, closes: Int) {
        self.opens = opens
        self.closes = closes
    }

    private enum CodingKeys: String, CodingKey { case opens, closes }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        opens = try ClockParsing.minutes(container.decode(String.self, forKey: .opens), codingPath: container.codingPath)
        closes = try ClockParsing.minutes(container.decode(String.self, forKey: .closes), codingPath: container.codingPath)
        guard closes > opens else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Closing time must be after opening time"))
        }
    }

    func isOpen(at minute: Int) -> Bool {
        minute >= opens && minute < closes
    }
}

/// A named busy spell, for example the after-school rush.
struct NamedPeriod: Hashable, Sendable, Decodable {
    let start: Int
    let end: Int
    let name: String

    init(start: Int, end: Int, name: String) {
        self.start = start
        self.end = end
        self.name = name
    }

    private enum CodingKeys: String, CodingKey { case start, end, name }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try ClockParsing.minutes(container.decode(String.self, forKey: .start), codingPath: container.codingPath)
        end = try ClockParsing.minutes(container.decode(String.self, forKey: .end), codingPath: container.codingPath)
        name = try container.decode(String.self, forKey: .name)
    }
}

/// A regular quiet hour, such as a weekday quiet hour from 9 to 10am.
struct QuietHour: Hashable, Sendable, Decodable {
    let start: Int
    let end: Int
    /// "weekdays", "daily" or nil.
    let days: String?

    init(start: Int, end: Int, days: String? = nil) {
        self.start = start
        self.end = end
        self.days = days
    }

    private enum CodingKeys: String, CodingKey { case start, end, days }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try ClockParsing.minutes(container.decode(String.self, forKey: .start), codingPath: container.codingPath)
        end = try ClockParsing.minutes(container.decode(String.self, forKey: .end), codingPath: container.codingPath)
        days = try container.decodeIfPresent(String.self, forKey: .days)
    }
}

/// Optional place-specific descriptions that replace the generic "How it feels" text.
struct FactorNotes: Hashable, Sendable, Decodable {
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

    func note(for factor: Factor) -> String? {
        switch factor {
        case .noise: noise
        case .light: light
        case .crowd: crowd
        case .smell: smell
        case .sudden: nil
        }
    }
}

/// A "Good to know" line on the place page.
struct GoodToKnow: Hashable, Sendable, Decodable {
    let kind: Kind
    let text: String

    enum Kind: String, Codable, Sendable {
        case quietSpace
        case quietHour
        case staff
        case access
        case seating
        case outdoor
        case toilets
        case lighting
        case booking
        case info

        var symbolName: String {
            switch self {
            case .quietSpace: "door.left.hand.open"
            case .quietHour: "clock"
            case .staff: "heart"
            case .access: "figure.roll"
            case .seating: "chair.lounge"
            case .outdoor: "leaf"
            case .toilets: "toilet"
            case .lighting: "lightbulb"
            case .booking: "calendar"
            case .info: "info.circle"
            }
        }
    }
}

/// Parses "HH:mm" strings into minutes since midnight. "24:00" means midnight at the end of the day.
enum ClockParsing {
    static func minutes(_ text: String, codingPath: [any CodingKey] = []) throws -> Int {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]), let minutes = Int(parts[1]),
              (0...24).contains(hours), (0..<60).contains(minutes),
              hours * 60 + minutes <= 24 * 60
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Expected a time like 09:30, got \(text)"))
        }
        return hours * 60 + minutes
    }
}

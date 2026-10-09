import Foundation

/// A place's personal status at one moment, plus its distance from the user.
struct PlaceSnapshot: Identifiable, Sendable {
    let place: Place
    let location: GeoPoint
    let status: TideStatus?
    let change: TideChange
    /// Straight-line metres from the user (or the demo centre).
    let distance: Double

    var id: String { place.id }
    var isOpen: Bool { status != nil }
    var walkMinutes: Int { Walking.minutes(forStraightLineMetres: distance) }

    init(place: Place, location: GeoPoint, engine: TideEngine, minute: Int, from reference: GeoPoint) {
        self.place = place
        self.location = location
        self.status = engine.status(of: place, at: minute)
        self.change = engine.nextChange(for: place, at: minute)
        self.distance = reference.distance(to: location)
    }

    /// "Calm until 3:30pm · 3 min walk", or "Busy now · calm from 3pm · 4 min walk".
    func statusLine(now: Int) -> String {
        let changeText = TideText.nextChange(change, now: now)
        let walk = TideText.walk(minutes: walkMinutes)
        switch status {
        case .calm, nil:
            return "\(changeText) · \(walk)"
        case .busy:
            return "Busy now · \(TideText.lowercasedFirst(changeText)) · \(walk)"
        case .high:
            return "High tide now · \(TideText.lowercasedFirst(changeText)) · \(walk)"
        }
    }
}

/// Filter chips under the map's search field.
enum CategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case cafes
    case libraries
    case parks
    case quietRooms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafes: "Cafés"
        case .libraries: "Libraries"
        case .parks: "Parks"
        case .quietRooms: "Quiet rooms"
        }
    }

    var categories: Set<PlaceCategory> {
        switch self {
        case .cafes: [.cafe]
        case .libraries: [.library]
        case .parks: [.park]
        case .quietRooms: [.quietRoom]
        }
    }
}

/// Search text, category and "Calm now". Pins show every match so you can see what to avoid;
/// with "Calm now" on, the sheet's list holds only places that are calm for you right now.
struct MapFilter: Equatable, Sendable {
    var calmOnly = true
    var category: CategoryFilter?
    var search = ""

    func showsPin(_ place: Place) -> Bool {
        if let category, !category.categories.contains(place.category) { return false }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return place.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Places for the sheet's list, nearest first. Closed places go last when "Calm now" is off.
    func listed(_ snapshots: [PlaceSnapshot]) -> [PlaceSnapshot] {
        snapshots
            .filter { showsPin($0.place) && (!calmOnly || $0.status == .calm) }
            .sorted { lhs, rhs in
                if lhs.isOpen != rhs.isOpen { return lhs.isOpen }
                return lhs.distance < rhs.distance
            }
    }
}

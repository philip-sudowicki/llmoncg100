import Foundation

/// Everything the map and list need to show one place right now, for this person.
struct PlaceSummary: Identifiable {
    let place: Place
    let position: GeoPoint
    let status: TideStatus?
    /// "Calm until 3:30pm".
    let statusLine: String
    /// "calm until 3:30pm", for VoiceOver.
    let spokenStatus: String
    let distance: Double

    var id: String { place.id }
    var walkMinutes: Int { Walking.estimatedMinutes(straightLineMetres: distance) }
    var walkText: String { "\(walkMinutes) min walk" }

    /// Summaries sorted by distance from `origin`.
    static func make(
        _ places: [Place],
        engine: TideEngine,
        minute: Int,
        anchor: GeoPoint,
        origin: GeoPoint
    ) -> [PlaceSummary] {
        let narrative = TideNarrative(engine: engine)
        return places.map { place in
            let position = place.position(around: anchor)
            return PlaceSummary(
                place: place,
                position: position,
                status: engine.status(of: place, atMinute: minute),
                statusLine: narrative.statusLine(for: place, atMinute: minute),
                spokenStatus: narrative.spokenStatus(for: place, atMinute: minute),
                distance: origin.distance(to: position)
            )
        }
        .sorted { $0.distance < $1.distance }
    }
}

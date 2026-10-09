import Foundation
@testable import Lowtide

/// Builds a place with flat values, then overrides chosen hours of a chosen factor.
func makePlace(
    id: String = "test-place",
    category: PlaceCategory = .library,
    offset: MetreOffset = MetreOffset(east: 0, north: 0),
    open: Int = 9 * 60,
    close: Int = 19 * 60,
    base: Double = 0.1,
    crowd: [Int: Double] = [:],
    sudden: [Int: Double] = [:],
    triggers: [Trigger] = [],
    busyPeriods: [BusyPeriod] = []
) -> Place {
    func series(_ overrides: [Int: Double]) -> [Double] {
        (0..<24).map { overrides[$0] ?? base }
    }
    return Place(
        id: id,
        name: "Test \(id)",
        category: category,
        street: "Test St",
        offset: offset,
        hours: OpeningHours(open: open, close: close),
        forecast: HourlyForecast(
            noiseDB: Array(repeating: 40, count: 24),
            sudden: series(sudden),
            light: series([:]),
            crowd: series(crowd),
            smell: series([:])
        ),
        triggers: triggers,
        goodToKnow: [],
        quietHour: nil,
        busyPeriods: busyPeriods,
        notes: FeelNotes()
    )
}

/// Minutes after midnight, for readable tests: `at(15, 30)`.
func at(_ hour: Int, _ minute: Int = 0) -> Int {
    hour * 60 + minute
}

enum SampleData {
    /// The bundled sample places. Inside the app host they come from the bundle; when the
    /// engine tests run on their own (for example with `swift test`) they come from the source tree.
    static func places() throws -> [Place] {
        let bundled = Bundle.main.url(forResource: "places", withExtension: "json")
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Lowtide/Data/places.json")
        return try LocalPlaceRepository.decode(Data(contentsOf: bundled ?? source))
    }
}

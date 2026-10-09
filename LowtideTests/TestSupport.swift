import Foundation
@testable import Lowtide

/// Minutes since midnight, for example `hour(15, 30)` for 3:30pm.
func hour(_ hour: Int, _ minute: Int = 0) -> Int {
    hour * 60 + minute
}

/// Builders for small synthetic places, so each test states exactly the curve it relies on.
enum TestPlaces {
    /// 24 values, all `base`, with specific hours overridden.
    static func series(_ base: Double, _ overrides: [Int: Double] = [:]) -> [Double] {
        (0..<24).map { overrides[$0] ?? base }
    }

    static func place(
        id: String = "test",
        opens: Int = hour(9),
        closes: Int = hour(19),
        noiseDB: [Double] = series(40),
        sudden: [Double] = series(0),
        light: [Double] = series(0),
        crowd: [Double] = series(0),
        smell: [Double] = series(0),
        periods: [NamedPeriod] = [],
        triggers: [PlaceTrigger] = []
    ) throws -> Place {
        Place(
            id: id,
            name: "Test Place",
            category: .library,
            street: "Test St",
            offset: MetreOffset(east: 0, north: 0),
            hours: OpeningHours(opens: opens, closes: closes),
            forecast: try Forecast(noiseDecibels: noiseDB, sudden: sudden, light: light, crowd: crowd, smell: smell),
            periods: periods,
            triggers: triggers
        )
    }

    /// The profile shown in the mockup.
    static let mockupProfile = SensoryProfile(sensitivities: [
        .noise: .aLot,
        .sudden: .aLot,
        .light: .some,
        .crowd: .some,
        .smell: .aBit,
    ])

    static let allSome = TideEngine(profile: .standard)
}

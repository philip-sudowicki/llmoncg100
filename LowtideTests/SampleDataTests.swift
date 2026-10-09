import XCTest
@testable import Lowtide

/// Checks the bundled `places.json` so the app keeps matching the mockup.
final class SampleDataTests: XCTestCase {
    private let engine = TideEngine(profile: TestPlaces.mockupProfile)

    private func places() throws -> [Place] {
        var repository = LocalPlaceRepository()
        // Outside the app (for example a plain SwiftPM run), point this at the JSON file instead.
        if repository.url == nil, let path = ProcessInfo.processInfo.environment["LOWTIDE_PLACES_JSON"] {
            repository = LocalPlaceRepository(url: URL(fileURLWithPath: path))
        }
        try XCTSkipIf(repository.url == nil, "places.json is bundled with the app target")
        return try repository.loadPlacesNow()
    }

    private func place(_ id: String) throws -> Place {
        let all = try places()
        return try XCTUnwrap(all.first { $0.id == id }, "Missing \(id)")
    }

    func testTenPlacesWithTheRequestedMix() throws {
        let places = try places()
        XCTAssertEqual(places.count, 10)
        XCTAssertEqual(Set(places.map(\.id)).count, 10)
        let counts = Dictionary(grouping: places, by: \.category).mapValues(\.count)
        XCTAssertEqual(counts[.library], 2)
        XCTAssertEqual(counts[.cafe], 3)
        XCTAssertEqual(counts[.park], 1)
        XCTAssertEqual(counts[.market], 1)
        XCTAssertEqual(counts[.station], 1)
        XCTAssertEqual(counts[.bookshop], 1)
        XCTAssertEqual(counts[.quietRoom], 1)
    }

    func testMarlowStreetLibraryIsCalmUntilHalfPastThree() throws {
        let library = try place("marlow-street-library")
        XCTAssertEqual(engine.status(of: library, at: hour(14)), .calm)
        let change = engine.nextChange(for: library, at: hour(14))
        XCTAssertEqual(TideText.nextChange(change, now: hour(14)), "Calm until 3:30pm")
        XCTAssertEqual(
            TideText.bestTime(engine.bestWindow(for: library, from: hour(14)), now: hour(14), closes: library.hours.closes),
            "Best time: now until 3:30pm"
        )
        XCTAssertEqual(TideText.takeaway(engine.takeaway(for: library)), "Usually calmest mid-afternoon")
        XCTAssertEqual(engine.headsUps(for: library).map(\.tag), [.handDryer, .bell])
    }

    func testFernAndFinchIsBusyAtLunch() throws {
        let cafe = try place("fern-and-finch")
        XCTAssertEqual(engine.status(of: cafe, at: hour(12, 30)), .busy)
        XCTAssertEqual(TestPlaces.allSome.status(of: cafe, at: hour(12, 30)), .busy)
        XCTAssertEqual(TestPlaces.allSome.status(of: cafe, at: hour(15, 30)), .calm)
    }

    func testNorthgateMarketIsHighTideMostOfTheDay() throws {
        let market = try place("northgate-market")
        let openHours = Array(stride(from: market.hours.opens, to: market.hours.closes, by: 60))
        let high = openHours.filter { engine.status(of: market, at: $0) == .high }
        XCTAssertGreaterThan(high.count * 2, openHours.count)
    }

    func testLarkspurGardensIsCalmMostOfTheDay() throws {
        let park = try place("larkspur-gardens")
        XCTAssertEqual(engine.status(of: park, at: hour(14)), .calm)
        XCTAssertEqual(TideText.nextChange(engine.nextChange(for: park, at: hour(14)), now: hour(14)), "Calm until 5pm")
        let calmMinutes = engine.calmWindows(for: park, from: park.hours.opens, to: park.hours.closes).map(\.duration).reduce(0, +)
        XCTAssertGreaterThan(calmMinutes, (park.hours.closes - park.hours.opens) / 2)
        XCTAssertEqual(TideText.takeaway(engine.takeaway(for: park)), "Usually calm for most of the day")
    }

    func testKingswayStationIsHighTideAtRushHours() throws {
        let station = try place("kingsway-station")
        XCTAssertEqual(engine.status(of: station, at: hour(8)), .high)
        XCTAssertEqual(engine.status(of: station, at: hour(17, 30)), .high)
        XCTAssertEqual(TestPlaces.allSome.status(of: station, at: hour(8)), .high)
        XCTAssertEqual(TestPlaces.allSome.status(of: station, at: hour(11)), .busy, "Quieter between the rushes")
    }
}

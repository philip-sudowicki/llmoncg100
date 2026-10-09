import XCTest
@testable import Lowtide

final class RepositoryTests: XCTestCase {
    private func json(places: String) -> Data {
        Data(#"{ "version": 1, "places": [\#(places)] }"#.utf8)
    }

    private func place(id: String, hours: Int = 24, closes: String = "19:00") -> String {
        let values = Array(repeating: "0.1", count: hours).joined(separator: ", ")
        let decibels = Array(repeating: "45", count: hours).joined(separator: ", ")
        return """
        {
          "id": "\(id)", "name": "Test", "category": "cafe", "street": "Test St",
          "offset": { "east": 10, "north": -20 },
          "hours": { "opens": "09:30", "closes": "\(closes)" },
          "forecast": { "noiseDB": [\(decibels)], "sudden": [\(values)], "light": [\(values)], "crowd": [\(values)], "smell": [\(values)] },
          "triggers": [{ "tag": "handDryer" }]
        }
        """
    }

    func testDecodesAPlace() throws {
        let places = try LocalPlaceRepository.decode(json(places: place(id: "a")))
        let decoded = try XCTUnwrap(places.first)
        XCTAssertEqual(decoded.hours, OpeningHours(opens: hour(9, 30), closes: hour(19)))
        XCTAssertEqual(decoded.forecast.noise[0], 0.125, accuracy: 0.0001, "45 dB normalises to 0.125")
        XCTAssertEqual(decoded.triggers.first?.label, "Hand dryer")
        XCTAssertTrue(decoded.goodToKnow.isEmpty, "Optional lists default to empty")
        XCTAssertNil(decoded.quietHour)
    }

    func testRejectsForecastsWithoutTwentyFourHours() {
        XCTAssertThrowsError(try LocalPlaceRepository.decode(json(places: place(id: "a", hours: 23))))
    }

    func testRejectsDuplicateIDs() {
        XCTAssertThrowsError(try LocalPlaceRepository.decode(json(places: place(id: "a") + "," + place(id: "a")))) { error in
            XCTAssertEqual(error as? PlaceRepositoryError, .duplicateID("a"))
        }
    }

    func testRejectsClosingBeforeOpening() {
        XCTAssertThrowsError(try LocalPlaceRepository.decode(json(places: place(id: "a", closes: "08:00"))))
    }

    func testMidnightClosingParses() throws {
        XCTAssertEqual(try ClockParsing.minutes("24:00"), 24 * 60)
        XCTAssertThrowsError(try ClockParsing.minutes("24:30"))
        XCTAssertThrowsError(try ClockParsing.minutes("9am"))
    }

    func testMissingFileThrows() async {
        let repository = LocalPlaceRepository(url: URL(fileURLWithPath: "/does/not/exist.json"))
        do {
            _ = try await repository.loadPlaces()
            XCTFail("Expected an error")
        } catch {
            // Expected.
        }
    }
}

final class DemoClockTests: XCTestCase {
    func testDemoClockReadsTheRequestedTimeToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let realNow = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 22, minute: 5)))
        let clock = DemoClock.startingAt(minute: hour(14), from: realNow, calendar: calendar)
        let shifted = realNow.addingTimeInterval(clock.offset)
        XCTAssertEqual(DemoClock.minuteOfDay(shifted, calendar: calendar), hour(14))
        XCTAssertTrue(clock.isShifted)
        XCTAssertFalse(DemoClock.real.isShifted)
    }

    func testRealClockMinuteOfDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15, minute: 30)))
        XCTAssertEqual(DemoClock.minuteOfDay(date, calendar: calendar), hour(15, 30))
    }
}

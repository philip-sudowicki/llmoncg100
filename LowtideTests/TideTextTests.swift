import XCTest
@testable import Lowtide

final class TideTextTests: XCTestCase {
    func testClockTimes() {
        XCTAssertEqual(TideText.clock(hour(0)), "12am")
        XCTAssertEqual(TideText.clock(hour(9)), "9am")
        XCTAssertEqual(TideText.clock(hour(10, 5)), "10:05am")
        XCTAssertEqual(TideText.clock(hour(12)), "12pm")
        XCTAssertEqual(TideText.clock(hour(15, 30)), "3:30pm")
        XCTAssertEqual(TideText.clock(hour(24)), "midnight")
    }

    func testRanges() {
        XCTAssertEqual(TideText.range(from: hour(9), to: hour(10)), "9–10am")
        XCTAssertEqual(TideText.range(from: hour(11), to: hour(13)), "11am–1pm")
        XCTAssertEqual(TideText.range(from: hour(15, 30), to: hour(17)), "3:30–5pm")
    }

    func testQuietHour() {
        let quietHour = QuietHour(start: hour(9), end: hour(10), days: "weekdays")
        XCTAssertEqual(TideText.quietHour(quietHour), "Quiet hour on weekdays, 9–10am")
    }

    func testSpokenStatusForPins() {
        XCTAssertEqual(TideText.spokenStatus(.calm, change: .calmUntil(hour(15, 30)), now: hour(14)), "calm until 3:30pm")
        XCTAssertEqual(TideText.spokenStatus(.busy, change: .calmFrom(hour(15)), now: hour(14)), "busy, calm from 3pm")
        XCTAssertEqual(TideText.spokenStatus(nil, change: .closed(opensAt: hour(9)), now: hour(20)), "closed, opens 9am")
    }

    func testOpeningLine() throws {
        let place = try TestPlaces.place(opens: hour(9), closes: hour(19))
        XCTAssertEqual(TideText.openingLine(for: place, now: hour(14)), "Open until 7pm")
        XCTAssertEqual(TideText.openingLine(for: place, now: hour(20)), "Closed · opens 9am")
    }

    func testWalkingEstimates() {
        XCTAssertEqual(Walking.minutes(forStraightLineMetres: 0), 1, "Never shows 0 minutes")
        XCTAssertEqual(Walking.minutes(forStraightLineMetres: 208), 3)
        XCTAssertEqual(TideText.walk(minutes: 3), "3 min walk")
    }

    func testHowItFeelsDescriptions() throws {
        let quiet = try TestPlaces.place(noiseDB: TestPlaces.series(45), crowd: TestPlaces.series(0.3))
        XCTAssertEqual(TideText.feeling(.noise, at: quiet, minute: hour(14)), "Quiet · about 45 dB")
        XCTAssertEqual(TideText.feeling(.crowd, at: quiet, minute: hour(14)), "A few people, plenty of space")
        XCTAssertEqual(TideText.feeling(.smell, at: quiet, minute: hour(14)), "Nothing noticed")

        let base = try TestPlaces.place()
        let noted = Place(
            id: "noted", name: "Noted", category: .library, street: "Test St",
            offset: MetreOffset(east: 0, north: 0), hours: base.hours, forecast: base.forecast,
            notes: FactorNotes(light: "Soft daylight, strip lights at the back")
        )
        XCTAssertEqual(TideText.feeling(.light, at: noted, minute: hour(14)), "Soft daylight, strip lights at the back")
    }

    func testMeterLevels() {
        XCTAssertEqual(TideText.meterLevel(0), 1)
        XCTAssertEqual(TideText.meterLevel(0.5), 3)
        XCTAssertEqual(TideText.meterLevel(1), 5)
    }

    func testCheckInLine() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 15)))
        let earlier = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14, minute: 14)))
        XCTAssertEqual(TideText.checkIn(.calm, at: earlier, today: today, calendar: calendar), "You checked in: Calm · 2:14pm")
    }

    func testLowWaterText() {
        XCTAssertEqual(TideText.calmPlaceAway(minutes: 1), "A calm place is a minute away.")
        XCTAssertEqual(TideText.calmPlaceAway(minutes: 2), "A calm place is two minutes away.")
        XCTAssertEqual(TideText.calmPlaceAway(minutes: 14), "A calm place is 14 minutes away.")
        XCTAssertEqual(TideText.lowWaterStatus(.calmUntil(hour(16, 55)), now: hour(14)), "Calm now · quiet until 5pm")
        XCTAssertEqual(TideText.distance(metres: 163), "160 m")
        XCTAssertEqual(TideText.distance(metres: 1_240), "1.2 km")
    }

    func testMetreOffsetsBecomeCoordinates() {
        let centre = GeoPoint.centralLondon
        let north = centre.offset(by: MetreOffset(east: 0, north: 111.32))
        XCTAssertEqual(north.latitude - centre.latitude, 0.001, accuracy: 0.000001)
        XCTAssertEqual(north.longitude, centre.longitude, accuracy: 0.000001)

        let east = centre.offset(by: MetreOffset(east: 200, north: 0))
        XCTAssertEqual(centre.distance(to: east), 200, accuracy: 0.5)
    }
}

final class SoundLevelTests: XCTestCase {
    func testDecibelsFromRMSUseTheCalibrationOffset() {
        // 0.001 RMS is -60 dBFS, which reads 40 dB with the 100 dB offset.
        XCTAssertEqual(SoundLevel.decibels(rms: 0.001), 40, accuracy: 0.001)
        XCTAssertEqual(SoundLevel.decibels(rms: 0.01), 60, accuracy: 0.001)
    }

    func testReadingsClampTo30Through110() {
        XCTAssertEqual(SoundLevel.decibels(rms: 0), 30)
        XCTAssertEqual(SoundLevel.decibels(rms: 0.000_001), 30)
        XCTAssertEqual(SoundLevel.decibels(rms: 10), 110)
    }

    func testDescriptions() {
        XCTAssertEqual(SoundLevel.describe(46), "Quiet conversation level")
        XCTAssertEqual(SoundLevel.describe(35), "Very quiet")
        XCTAssertEqual(SoundLevel.describe(72), "Loud, like busy traffic")
        XCTAssertEqual(SoundLevel.noiseWord(45), "Quiet")
        XCTAssertEqual(SoundLevel.roundedForDisplay(46), 45)
    }

    func testMeterLevels() {
        XCTAssertEqual(SoundLevel.meterLevel(30), 1)
        XCTAssertEqual(SoundLevel.meterLevel(60), 3)
        XCTAssertEqual(SoundLevel.meterLevel(110), 5)
    }
}

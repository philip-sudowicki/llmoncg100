import Foundation
import Testing
@testable import Lowtide

@Suite("Time text")
struct TimeTextTests {
    @Test("12-hour times", arguments: [
        (0, "midnight"), (540, "9am"), (720, "12pm"), (930, "3:30pm"), (1425, "11:45pm"), (1440, "midnight"),
    ])
    func twelveHour(minute: Int, expected: String) {
        #expect(TimeText.time(minute, style: .twelveHour) == expected)
    }

    @Test func twentyFourHour() {
        #expect(TimeText.time(930, style: .twentyFourHour) == "15:30")
        #expect(TimeText.time(540, style: .twentyFourHour) == "09:00")
    }

    @Test func ranges() {
        #expect(TimeText.range(from: at(9), to: at(10), style: .twelveHour) == "9–10am")
        #expect(TimeText.range(from: at(11), to: at(13), style: .twelveHour) == "11am–1pm")
        #expect(TimeText.range(from: at(16, 30), to: at(19), style: .twelveHour) == "4:30–7pm")
        #expect(TimeText.range(from: at(9), to: at(10), style: .twentyFourHour) == "09:00–10:00")
    }

    @Test func clockTimeParsing() {
        #expect(ClockTime.minutes(from: "09:30") == 570)
        #expect(ClockTime.minutes(from: "24:00") == 1440)
        #expect(ClockTime.minutes(from: "25:00") == nil)
        #expect(ClockTime.minutes(from: "9.30") == nil)
    }
}

@Suite("Sound and walking")
struct MeasureTests {
    @Test func decibelsFromRMS() {
        #expect(abs(SoundLevel.decibels(fromRMS: 1.0, calibrationOffset: 100) - 100) < 0.001)
        #expect(abs(SoundLevel.decibels(fromRMS: 0.001, calibrationOffset: 100) - 40) < 0.001)
        #expect(SoundLevel.decibels(fromRMS: 0, calibrationOffset: 100) == 30)
        #expect(SoundLevel.decibels(fromRMS: 10, calibrationOffset: 100) == 110)
    }

    @Test func soundDescriptions() {
        #expect(SoundLevel.description(forDecibels: 46) == "Quiet conversation level")
        #expect(SoundLevel.feel(forDecibels: 45) == "Quiet")
        #expect(SoundLevel.approximate(46) == "about 45 dB")
    }

    @Test func meterSteps() {
        #expect(FeelText.meterSteps(0) == 1)
        #expect(FeelText.meterSteps(0.21) == 2)
        #expect(FeelText.meterSteps(0.6) == 3)
        #expect(FeelText.meterSteps(1.4) == 5)
    }

    @Test func walkingEstimates() {
        #expect(Walking.estimatedMinutes(straightLineMetres: 139) == 3)
        #expect(Walking.estimatedMinutes(straightLineMetres: 5) == 1)
        #expect(Walking.minutes(forTravelTime: 125) == 2)
        #expect(Walking.distanceText(metres: 163) == "160 m")
        #expect(Walking.distanceText(metres: 1240) == "1.2 km")
        #expect(Walking.spokenMinutes(2) == "two minutes")
        #expect(Walking.spokenMinutes(1) == "one minute")
        #expect(Walking.spokenMinutes(14) == "14 minutes")
    }

    @Test func offsetsBecomePositions() {
        let anchor = GeoPoint.londonFallback
        let north = anchor.offsetBy(east: 0, north: 100)
        let east = anchor.offsetBy(east: 100, north: 0)
        #expect(abs(anchor.distance(to: north) - 100) < 1)
        #expect(abs(anchor.distance(to: east) - 100) < 1)
    }
}

@Suite("Filters and low water")
struct FilterTests {
    let engine = TideEngine(profile: .standard)
    let calmCafe = makePlace(id: "calm-cafe", category: .cafe, offset: MetreOffset(east: 300, north: 0))
    let busyCafe = makePlace(id: "busy-cafe", category: .cafe, offset: MetreOffset(east: 50, north: 0), base: 0.5)
    let calmPark = makePlace(id: "calm-park", category: .park, offset: MetreOffset(east: 100, north: 0))
    let farLibrary = makePlace(id: "far-library", offset: MetreOffset(east: 900, north: 0))
    let nearLibrary = makePlace(id: "near-library", offset: MetreOffset(east: 0, north: 200))

    var places: [Place] { [calmCafe, busyCafe, calmPark, farLibrary, nearLibrary] }

    @Test func calmNowLimitsTheList() {
        let filter = PlaceFilter()
        #expect(filter.mapPlaces(places).count == 5)
        #expect(filter.listPlaces(places, engine: engine, atMinute: at(12)).map(\.id).contains("busy-cafe") == false)
    }

    @Test func chipsFilterByCategory() {
        var filter = PlaceFilter(calmNow: false)
        filter.chips = [.cafes]
        #expect(filter.listPlaces(places, engine: engine, atMinute: at(12)).map(\.id) == ["calm-cafe", "busy-cafe"])
    }

    @Test func searchFindsPlacesThatAreNotCalm() {
        var filter = PlaceFilter()
        filter.searchText = "busy"
        #expect(filter.listPlaces(places, engine: engine, atMinute: at(12)).map(\.id) == ["busy-cafe"])
    }

    @Test func lowWaterPicksTheNearestCalmPlaces() {
        let anchor = GeoPoint.londonFallback
        let picks = LowWaterPicker.candidates(
            from: places, engine: engine, atMinute: at(12), origin: anchor, anchor: anchor
        )
        #expect(picks.map(\.id) == ["calm-park", "near-library", "calm-cafe"])
    }
}

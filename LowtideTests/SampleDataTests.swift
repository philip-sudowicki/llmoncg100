import Testing
@testable import Lowtide

/// The bundled sample data should tell the same story as the mockup.
@Suite("Sample data")
struct SampleDataTests {
    let places: [Place]
    let engine = TideEngine(profile: .standard)
    let narrative = TideNarrative(engine: TideEngine(profile: .standard), style: .twelveHour)
    let mockupTime = at(14, 10)

    init() throws {
        places = try SampleData.places()
    }

    private func place(_ id: String) throws -> Place {
        try #require(places.first { $0.id == id })
    }

    @Test func tenPlacesInTheRightMix() {
        #expect(places.count == 10)
        #expect(Set(places.map(\.id)).count == 10)
        let counts = Dictionary(grouping: places, by: \.category).mapValues(\.count)
        #expect(counts == [.library: 2, .cafe: 3, .park: 1, .market: 1, .station: 1, .bookshop: 1, .quietRoom: 1])
    }

    @Test func marlowStreetLibraryIsCalmUntilHalfPastThree() throws {
        let library = try place("marlow-street-library")
        #expect(engine.status(of: library, atMinute: mockupTime) == .calm)
        #expect(narrative.statusLine(for: library, atMinute: mockupTime) == "Calm until 3:30pm")
        #expect(narrative.bannerDetail(for: library, atMinute: mockupTime)
            == "Calm until about 3:30pm, then the after-school rush.")
        #expect(narrative.bestTimeLine(for: library, atMinute: mockupTime) == "Best time: now until 3:30pm")
        #expect(narrative.takeaway(for: library) == "Usually calmest mid-afternoon")
        #expect(narrative.hoursLine(for: library, atMinute: mockupTime) == "Open until 7pm")
        #expect(engine.headsUp(for: library).map(\.text) == [
            "Hand dryer in toilets", "Closing bell at 6:45pm", "Strip lights at the back",
        ])
    }

    @Test func fernAndFinchIsBusyAtLunch() throws {
        let cafe = try place("fern-and-finch")
        #expect(engine.status(of: cafe, atMinute: at(12, 30)) == .busy)
        #expect(engine.status(of: cafe, atMinute: mockupTime) == .busy)
        #expect(narrative.statusLine(for: cafe, atMinute: mockupTime) == "Calm from 3pm")
    }

    @Test func northgateMarketIsHighTideMostOfTheDay() throws {
        let market = try place("northgate-market")
        let openMinutes = Array(stride(from: market.hours.open, to: market.hours.close, by: 30))
        let high = openMinutes.filter { engine.status(of: market, atMinute: $0) == .high }
        #expect(Double(high.count) / Double(openMinutes.count) > 0.6)
        #expect(engine.status(of: market, atMinute: mockupTime) == .high)
    }

    @Test func larkspurGardensIsCalmMostOfTheDay() throws {
        let park = try place("larkspur-gardens")
        #expect(narrative.statusLine(for: park, atMinute: mockupTime) == "Calm until 5pm")
        let openMinutes = Array(stride(from: park.hours.open, to: park.hours.close, by: 30))
        let calm = openMinutes.filter { engine.status(of: park, atMinute: $0) == .calm }
        #expect(Double(calm.count) / Double(openMinutes.count) > 0.75)
    }

    @Test func kingswayStationIsHighTideAtRushHours() throws {
        let station = try place("kingsway-station")
        #expect(engine.status(of: station, atMinute: at(8)) == .high)
        #expect(engine.status(of: station, atMinute: at(17, 30)) == .high)
        #expect(engine.status(of: station, atMinute: at(11)) != .high)
    }

    @Test func everyPlaceHasSomethingGoodToKnow() {
        for place in places {
            #expect(!place.goodToKnow.isEmpty, "\(place.name) has no good-to-know lines")
        }
    }
}

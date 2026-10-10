import XCTest
@testable import Lowtide

final class MapFilterTests: XCTestCase {
    private let reference = GeoPoint.centralLondon

    private func snapshot(_ id: String, category: PlaceCategory = .library, metresNorth: Double, crowd: Double, closes: Int = hour(19)) throws -> PlaceSnapshot {
        let base = try TestPlaces.place(id: id, closes: closes, crowd: TestPlaces.series(crowd))
        let place = Place(
            id: id, name: id.capitalized, category: category, street: "Test St",
            offset: MetreOffset(east: 0, north: metresNorth),
            hours: base.hours, forecast: base.forecast
        )
        return PlaceSnapshot(
            place: place,
            location: reference.offset(by: place.offset),
            engine: TestPlaces.allSome,
            minute: hour(14),
            from: reference
        )
    }

    func testCalmNowListsOnlyCalmPlacesNearestFirst() throws {
        let snapshots = [
            try snapshot("far", metresNorth: 500, crowd: 0.1),
            try snapshot("busy", metresNorth: 50, crowd: 0.5),
            try snapshot("near", metresNorth: 100, crowd: 0.1),
        ]
        XCTAssertEqual(MapFilter(calmOnly: true).listed(snapshots).map(\.id), ["near", "far"])
        XCTAssertEqual(MapFilter(calmOnly: false).listed(snapshots).map(\.id), ["busy", "near", "far"])
    }

    func testClosedPlacesGoLastWhenCalmNowIsOff() throws {
        let snapshots = [
            try snapshot("closed", metresNorth: 10, crowd: 0.1, closes: hour(12)),
            try snapshot("open", metresNorth: 400, crowd: 0.1),
        ]
        XCTAssertEqual(MapFilter(calmOnly: false).listed(snapshots).map(\.id), ["open", "closed"])
    }

    func testCategoryAndSearchFilterPins() throws {
        let cafe = try snapshot("fern", category: .cafe, metresNorth: 10, crowd: 0.1).place
        let library = try snapshot("marlow", category: .library, metresNorth: 10, crowd: 0.1).place
        XCTAssertTrue(MapFilter(category: .cafes).showsPin(cafe))
        XCTAssertFalse(MapFilter(category: .cafes).showsPin(library))
        XCTAssertTrue(MapFilter(search: "MAR").showsPin(library), "Search ignores case")
        XCTAssertFalse(MapFilter(search: "kettle").showsPin(library))
    }

    func testStaysCalmNeedsTheWalkPlusAMargin() throws {
        // Calm until about 3:24pm, then busy; 208 m is a 3 minute walk.
        let base = try snapshot("soon-busy", metresNorth: 208, crowd: 0.1)
        let place = try TestPlaces.place(id: "soon-busy", crowd: TestPlaces.series(0.2, [15: 0.3, 16: 0.55]))
        let soonBusy = PlaceSnapshot(place: place, location: base.location, engine: TestPlaces.allSome, minute: hour(15, 5), from: reference)
        XCTAssertTrue(soonBusy.staysCalm(afterWalkingFrom: hour(15, 5)), "Busy from 3:24pm, arriving 3:08pm + 10 min margin")
        let late = PlaceSnapshot(place: place, location: base.location, engine: TestPlaces.allSome, minute: hour(15, 15), from: reference)
        XCTAssertFalse(late.staysCalm(afterWalkingFrom: hour(15, 15)), "Arriving 3:18pm leaves under 10 calm minutes")

        let closesSoon = try snapshot("closes", metresNorth: 208, crowd: 0.1, closes: hour(17))
        let atTen = PlaceSnapshot(place: closesSoon.place, location: closesSoon.location, engine: TestPlaces.allSome, minute: hour(16, 50), from: reference)
        XCTAssertFalse(atTen.staysCalm(afterWalkingFrom: hour(16, 50)), "Closes before the user would settle in")
    }

    func testStatusLines() throws {
        let calm = try snapshot("calm", metresNorth: 208, crowd: 0.1)
        XCTAssertEqual(calm.statusLine(now: hour(14)), "Calm until 7pm · 3 min walk")
        let busy = try snapshot("busy", metresNorth: 208, crowd: 0.5)
        XCTAssertEqual(busy.statusLine(now: hour(14)), "Busy now · not calm again today · 3 min walk")
    }
}

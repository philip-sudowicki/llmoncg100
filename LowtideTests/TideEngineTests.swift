import XCTest
@testable import Lowtide

final class TideEngineTests: XCTestCase {
    // MARK: Weights and normalisation

    func testSensitivityWeights() {
        XCTAssertEqual(Sensitivity.aBit.weight, 0.5)
        XCTAssertEqual(Sensitivity.some.weight, 1.0)
        XCTAssertEqual(Sensitivity.aLot.weight, 1.6)
    }

    func testMissingSensitivityDefaultsToSome() {
        let engine = TideEngine(sensitivities: [:])
        XCTAssertEqual(engine.weight(for: .crowd), 1.0)
    }

    func testNoiseIsNormalisedFromDecibels() {
        XCTAssertEqual(Forecast.normalisedNoise(decibels: 40), 0)
        XCTAssertEqual(Forecast.normalisedNoise(decibels: 60), 0.5)
        XCTAssertEqual(Forecast.normalisedNoise(decibels: 80), 1)
        XCTAssertEqual(Forecast.normalisedNoise(decibels: 25), 0, "Quieter than 40 dB clamps to 0")
        XCTAssertEqual(Forecast.normalisedNoise(decibels: 95), 1, "Louder than 80 dB clamps to 1")
    }

    // MARK: Thresholds

    func testStatusThresholds() {
        XCTAssertEqual(TideEngine.status(forScore: 0), .calm)
        XCTAssertEqual(TideEngine.status(forScore: 0.39), .calm)
        XCTAssertEqual(TideEngine.status(forScore: 0.4), .busy, "0.4 is no longer calm")
        XCTAssertEqual(TideEngine.status(forScore: 0.69), .busy)
        XCTAssertEqual(TideEngine.status(forScore: 0.7), .high, "0.7 or above is high tide")
        XCTAssertEqual(TideEngine.status(forScore: 1.6), .high)
    }

    func testStatusGlyphsUseDifferentWaveCounts() {
        XCTAssertEqual(TideStatus.calm.waveCount, 1)
        XCTAssertEqual(TideStatus.busy.waveCount, 2)
        XCTAssertEqual(TideStatus.high.waveCount, 3)
    }

    // MARK: Max rule

    func testWorstWeightedFactorDominates() {
        let levels = FactorLevels(noise: 0.3, sudden: 0, light: 0.5, crowd: 0.2, smell: 0)
        let noiseSensitive = TideEngine(sensitivities: [.noise: .aLot, .light: .aBit, .crowd: .some])
        XCTAssertEqual(noiseSensitive.score(levels), 0.48, accuracy: 0.0001, "0.3 × 1.6 beats 0.5 × 0.5")
        XCTAssertEqual(TideEngine.status(forScore: noiseSensitive.score(levels)), .busy)

        let relaxed = TideEngine(sensitivities: [.noise: .aBit, .light: .aBit, .crowd: .some])
        XCTAssertEqual(relaxed.score(levels), 0.25, accuracy: 0.0001)
        XCTAssertEqual(TideEngine.status(forScore: relaxed.score(levels)), .calm)
    }

    func testOneBadFactorIsEnoughForHighTide() {
        let levels = FactorLevels(noise: 0, sudden: 0, light: 0, crowd: 0, smell: 0.9)
        XCTAssertEqual(TestPlaces.allSome.score(levels), 0.9, accuracy: 0.0001)
        XCTAssertEqual(TideEngine.status(forScore: TestPlaces.allSome.score(levels)), .high)
    }

    func testClosedPlaceHasNoStatus() throws {
        let place = try TestPlaces.place(opens: hour(9, 0), closes: hour(19, 0))
        XCTAssertNil(TestPlaces.allSome.status(of: place, at: hour(8, 59)))
        XCTAssertEqual(TestPlaces.allSome.status(of: place, at: hour(9, 0)), .calm)
        XCTAssertEqual(TestPlaces.allSome.status(of: place, at: hour(18, 59)), .calm)
        XCTAssertNil(TestPlaces.allSome.status(of: place, at: hour(19, 0)), "Closing time is closed")
    }

    // MARK: Interpolation

    func testValuesInterpolateBetweenHours() {
        let values = TestPlaces.series(0, [14: 0.2, 15: 0.6])
        XCTAssertEqual(Forecast.interpolate(values, at: Double(hour(14, 0))), 0.2, accuracy: 0.0001)
        XCTAssertEqual(Forecast.interpolate(values, at: Double(hour(14, 30))), 0.4, accuracy: 0.0001)
        XCTAssertEqual(Forecast.interpolate(values, at: Double(hour(14, 45))), 0.5, accuracy: 0.0001)
    }

    func testInterpolationWrapsPastMidnight() {
        let values = TestPlaces.series(0, [23: 1.0, 0: 0.0])
        XCTAssertEqual(Forecast.interpolate(values, at: Double(hour(23, 30))), 0.5, accuracy: 0.0001)
    }

    // MARK: Next change

    func testCalmUntilHalfPastFromInterpolatedCrossing() throws {
        // Crowd crosses 0.4 at about 3:25pm, which shows to the nearest half hour.
        let place = try TestPlaces.place(crowd: TestPlaces.series(0.2, [15: 0.33, 16: 0.5]))
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(14))
        XCTAssertEqual(change, .calmUntil(hour(15, 25)))
        XCTAssertEqual(TideText.nextChange(change, now: hour(14)), "Calm until 3:30pm")
    }

    func testCalmFromWhenBusyNow() throws {
        let place = try TestPlaces.place(crowd: TestPlaces.series(0.2, [12: 0.6, 13: 0.6, 14: 0.2]))
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(12))
        guard case .calmFrom(let minute) = change else {
            return XCTFail("Expected calmFrom, got \(change)")
        }
        XCTAssertEqual(Double(minute), Double(hour(13, 30)), accuracy: 1)
        XCTAssertEqual(TideText.nextChange(change, now: hour(12)), "Calm from 1:30pm")
    }

    func testCalmUntilClosing() throws {
        let place = try TestPlaces.place(closes: hour(19))
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(10))
        XCTAssertEqual(change, .calmUntilClosing(hour(19)))
        XCTAssertEqual(TideText.nextChange(change, now: hour(10)), "Calm until 7pm")
    }

    func testNotCalmAgainToday() throws {
        let place = try TestPlaces.place(crowd: TestPlaces.series(0.8))
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(10))
        XCTAssertEqual(change, .notCalmAgainToday)
        XCTAssertEqual(TideText.nextChange(change, now: hour(10)), "Not calm again today")
    }

    func testClosedChangeNamesOpeningTime() throws {
        let place = try TestPlaces.place(opens: hour(9), closes: hour(19))
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(21))
        XCTAssertEqual(change, .closed(opensAt: hour(9)))
        XCTAssertEqual(TideText.nextChange(change, now: hour(21)), "Closed · opens 9am")
    }

    func testDisplayedChangeIsNeverInThePast() {
        // 2:44pm rounds to 2:30pm, which has passed at 2:40pm, so show 2:45pm instead.
        XCTAssertEqual(TideText.displayMinute(hour(14, 44), now: hour(14, 40)), hour(14, 45))
        XCTAssertEqual(TideText.displayMinute(hour(15, 25), now: hour(14)), hour(15, 30))
        XCTAssertEqual(TideText.displayMinute(hour(15, 14), now: hour(14)), hour(15, 0))
    }

    func testBannerMentionsTheNextRush() throws {
        let place = try TestPlaces.place(
            crowd: TestPlaces.series(0.2, [15: 0.33, 16: 0.5]),
            periods: [NamedPeriod(start: hour(15, 30), end: hour(17), name: "the after-school rush")]
        )
        let change = TestPlaces.allSome.nextChange(for: place, at: hour(14))
        let banner = TideText.banner(status: .calm, change: change, now: hour(14), place: place)
        XCTAssertEqual(banner.title, "Low tide now")
        XCTAssertEqual(banner.detail, "Calm until about 3:30pm, then the after-school rush.")
    }

    // MARK: Best window

    func testBestWindowIsTheLongestCalmSpellBeforeClosing() throws {
        // Calm 9–10:30am (short), busy until 1:30pm, calm 1:30–5:30pm (long), then busy.
        let crowd = TestPlaces.series(0.2, [10: 0.2, 11: 0.6, 12: 0.6, 13: 0.6, 14: 0.2, 17: 0.2, 18: 0.6])
        let place = try TestPlaces.place(crowd: crowd)
        let best = try XCTUnwrap(TestPlaces.allSome.bestWindow(for: place, from: hour(9)))
        XCTAssertEqual(Double(best.start), Double(hour(13, 30)), accuracy: 1)
        XCTAssertEqual(Double(best.end), Double(hour(17, 30)), accuracy: 1)
    }

    func testBestWindowStartsNowWhenAlreadyCalm() throws {
        let place = try TestPlaces.place(crowd: TestPlaces.series(0.2, [16: 0.2, 17: 0.6]))
        let best = try XCTUnwrap(TestPlaces.allSome.bestWindow(for: place, from: hour(14, 10)))
        XCTAssertEqual(best.start, hour(14, 10))
        XCTAssertEqual(TideText.bestTime(best, now: hour(14, 10), closes: place.hours.closes), "Best time: now until 4:30pm")
    }

    func testBestWindowEndsAtClosing() throws {
        let place = try TestPlaces.place(closes: hour(18, 30))
        let best = try XCTUnwrap(TestPlaces.allSome.bestWindow(for: place, from: hour(16)))
        XCTAssertEqual(best, TimeWindow(start: hour(16), end: hour(18, 30)))
        XCTAssertEqual(TideText.bestTime(best, now: hour(16), closes: hour(18, 30)), "Best time: now until 6:30pm")
    }

    func testBestWindowTieGoesToTheEarlierWindow() throws {
        // Two identically shaped calm spells, 8:40–10:20am and 12:40–2:20pm.
        let crowd = TestPlaces.series(0.8, [9: 0.2, 10: 0.2, 13: 0.2, 14: 0.2])
        let place = try TestPlaces.place(opens: hour(8), crowd: crowd)
        let windows = TestPlaces.allSome.calmWindows(for: place, from: hour(8), to: place.hours.closes)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].duration, windows[1].duration, "Precondition: equal lengths")
        XCTAssertEqual(TestPlaces.allSome.bestWindow(for: place, from: hour(8)), windows[0])
    }

    func testNoBestWindowWhenNeverCalm() throws {
        let place = try TestPlaces.place(noiseDB: TestPlaces.series(70))
        XCTAssertNil(TestPlaces.allSome.bestWindow(for: place, from: hour(9)))
        XCTAssertEqual(TideText.bestTime(nil, now: hour(9), closes: hour(19)), "No calm time left today")
    }

    func testNextCalmWindowSkipsTheCurrentOne() throws {
        let crowd = TestPlaces.series(0.2, [11: 0.6, 12: 0.6, 13: 0.2])
        let place = try TestPlaces.place(crowd: crowd)
        let next = try XCTUnwrap(TestPlaces.allSome.nextCalmWindow(for: place, after: hour(9, 30)))
        XCTAssertGreaterThan(next.start, hour(12))
    }

    func testGoodMatchNeedsThreeCalmHours() throws {
        let place = try TestPlaces.place(closes: hour(19), crowd: TestPlaces.series(0.2, [15: 0.2, 16: 0.6]))
        XCTAssertTrue(TestPlaces.allSome.isGoodMatch(place, at: hour(9)))
        XCTAssertFalse(TestPlaces.allSome.isGoodMatch(place, at: hour(13)), "Busy within three hours")
        XCTAssertFalse(TestPlaces.allSome.isGoodMatch(place, at: hour(20)), "Closed")
    }

    func testTakeawayNamesThePartOfDay() throws {
        let crowd = TestPlaces.series(0.6, [13: 0.6, 14: 0.2, 15: 0.2, 16: 0.6])
        let place = try TestPlaces.place(crowd: crowd)
        XCTAssertEqual(TideText.takeaway(TestPlaces.allSome.takeaway(for: place)), "Usually calmest mid-afternoon")
    }

    func testTakeawayForPlacesThatAreCalmAllOrMostOfTheDay() throws {
        let allDay = try TestPlaces.place()
        XCTAssertEqual(TestPlaces.allSome.takeaway(for: allDay), .calmAllDay)
        let mostOfTheDay = try TestPlaces.place(crowd: TestPlaces.series(0.2, [17: 0.2, 18: 0.8]))
        XCTAssertEqual(TestPlaces.allSome.takeaway(for: mostOfTheDay), .calmMostOfTheDay)
    }

    func testTakeawayFallsBackToQuietestTime() throws {
        let place = try TestPlaces.place(crowd: TestPlaces.series(0.9, [10: 0.5]))
        XCTAssertEqual(TideText.takeaway(TestPlaces.allSome.takeaway(for: place)), "Rarely calm for you. Quietest around 10am")
    }

    func testCurveCoversOpeningHours() throws {
        let place = try TestPlaces.place(opens: hour(9), closes: hour(19))
        let curve = TestPlaces.allSome.curve(for: place, step: 30)
        XCTAssertEqual(curve.first?.minute, hour(9))
        XCTAssertEqual(curve.last?.minute, hour(19))
        XCTAssertEqual(curve.count, 21)
    }

    // MARK: Triggers

    func testTriggerTagsMapToFactors() {
        XCTAssertEqual(TriggerTag.handDryer.factor, .sudden)
        XCTAssertEqual(TriggerTag.music.factor, .noise)
        XCTAssertEqual(TriggerTag.coffeeGrinder.factor, .sudden)
        XCTAssertEqual(TriggerTag.stripLights.factor, .light)
        XCTAssertEqual(TriggerTag.bell.factor, .sudden)
        XCTAssertEqual(TriggerTag.perfume.factor, .smell)
    }

    func testHeadsUpsShowForSomeOrALot() throws {
        let place = try TestPlaces.place(triggers: [
            PlaceTrigger(tag: .handDryer, label: "Hand dryer in toilets"),
            PlaceTrigger(tag: .perfume),
            PlaceTrigger(tag: .stripLights),
        ])
        let engine = TideEngine(sensitivities: [.sudden: .aLot, .smell: .aBit, .light: .some])
        XCTAssertEqual(engine.headsUps(for: place).map(\.tag), [.handDryer, .stripLights])
        XCTAssertEqual(engine.headsUps(for: place).first?.label, "Hand dryer in toilets")
        XCTAssertEqual(PlaceTrigger(tag: .perfume).label, "Perfume", "Falls back to the tag's default label")
    }

    func testNoHeadsUpsWhenEverythingIsABit() throws {
        let place = try TestPlaces.place(triggers: [PlaceTrigger(tag: .handDryer), PlaceTrigger(tag: .music)])
        let engine = TideEngine(sensitivities: Dictionary(uniqueKeysWithValues: Factor.allCases.map { ($0, Sensitivity.aBit) }))
        XCTAssertTrue(engine.headsUps(for: place).isEmpty)
    }
}

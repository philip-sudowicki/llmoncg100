import Testing
@testable import Lowtide

@Suite("Status thresholds")
struct ThresholdTests {
    @Test("Below 0.4 is calm, below 0.7 is busy, 0.7 and above is high tide", arguments: [
        (0.0, TideStatus.calm), (0.39, .calm), (0.4, .busy), (0.55, .busy),
        (0.69, .busy), (0.7, .high), (1.0, .high), (1.6, .high),
    ])
    func thresholds(score: Double, expected: TideStatus) {
        #expect(TideStatus(score: score) == expected)
    }

    @Test func waveCountsNeverRelyOnColourAlone() {
        #expect(TideStatus.allCases.map(\.waveCount) == [1, 2, 3])
    }

    @Test("Noise is clamp((dB - 40) / 40, 0, 1)", arguments: [
        (30.0, 0.0), (40.0, 0.0), (50.0, 0.25), (60.0, 0.5), (80.0, 1.0), (95.0, 1.0),
    ])
    func noiseNormalisation(decibels: Double, expected: Double) {
        #expect(abs(TideEngine.normalisedNoise(decibels: decibels) - expected) < 0.0001)
    }

    @Test func closedPlacesHaveNoStatus() {
        let place = makePlace(open: at(9), close: at(17))
        let engine = TideEngine(profile: .standard)
        #expect(engine.status(of: place, atMinute: at(8, 59)) == nil)
        #expect(engine.status(of: place, atMinute: at(9)) == .calm)
        #expect(engine.status(of: place, atMinute: at(17)) == nil)
    }
}

@Suite("Personal score")
struct ScoreTests {
    let values = FactorValues(noise: 0.3, sudden: 0.1, light: 0.2, crowd: 0.35, smell: 0)

    @Test func theWorstFactorDominates() {
        let engine = TideEngine(profile: .standard)
        #expect(abs(engine.score(values) - 0.35) < 0.0001)
    }

    @Test func weightsAreABitSomeALot() {
        #expect(Sensitivity.mild.weight == 0.5)
        #expect(Sensitivity.moderate.weight == 1.0)
        #expect(Sensitivity.strong.weight == 1.6)
    }

    @Test func aSensitiveFactorCanTakeOver() {
        var profile = SensoryProfile.standard
        profile.noise = .strong
        let engine = TideEngine(profile: profile)
        // Noise 0.3 × 1.6 = 0.48 beats crowd 0.35 × 1.0.
        #expect(abs(engine.score(values) - 0.48) < 0.0001)
        #expect(TideStatus(score: engine.score(values)) == .busy)
    }

    @Test func lowSensitivityCalmsEverything() {
        var profile = SensoryProfile.standard
        for factor in Factor.allCases { profile[sensitivity: factor] = .mild }
        let engine = TideEngine(profile: profile)
        #expect(abs(engine.score(values) - 0.175) < 0.0001)
    }

    @Test func halfHoursAreInterpolated() {
        let place = makePlace(crowd: [14: 0.2, 15: 0.6])
        let engine = TideEngine(profile: .standard)
        #expect(abs(engine.score(of: place, atMinute: at(14, 30)) - 0.4) < 0.0001)
        #expect(engine.status(of: place, atMinute: at(14, 15)) == .calm)
        #expect(engine.status(of: place, atMinute: at(14, 30)) == .busy)
    }
}

@Suite("Next change")
struct NextChangeTests {
    let engine = TideEngine(profile: .standard)

    @Test func calmUntilAHalfHour() {
        // 15:00 is 0.3 and 16:00 is 0.6, so 15:30 interpolates to 0.45: busy.
        let place = makePlace(crowd: [15: 0.3, 16: 0.6, 17: 0.6, 18: 0.6])
        let change = engine.nextChange(for: place, atMinute: at(14, 10))
        #expect(change == .calmUntil(at(15, 30)))
        #expect(change.text(style: .twelveHour) == "Calm until 3:30pm")
    }

    @Test func calmFromTheHour() {
        let place = makePlace(crowd: [12: 0.6, 13: 0.6, 14: 0.5, 15: 0.3])
        let change = engine.nextChange(for: place, atMinute: at(12, 20))
        // 14:30 interpolates to 0.4 (busy), 15:00 is 0.3 (calm).
        #expect(change == .calmFrom(at(15)))
        #expect(change.text(style: .twelveHour) == "Calm from 3pm")
    }

    @Test func calmUntilClosing() {
        let place = makePlace(close: at(18))
        let change = engine.nextChange(for: place, atMinute: at(16))
        #expect(change == .calmUntilClosing(at(18)))
        #expect(change.text(style: .twelveHour) == "Calm until it closes at 6pm")
    }

    @Test func noCalmBeforeClosing() {
        let place = makePlace(close: at(18), base: 0.8)
        let change = engine.nextChange(for: place, atMinute: at(10))
        #expect(change == .noCalmBeforeClosing(at(18)))
        #expect(change.text(style: .twelveHour) == "No calm time before it closes at 6pm")
    }

    @Test func closedPlacesSayWhenTheyOpen() {
        let place = makePlace(open: at(9), close: at(17))
        #expect(engine.nextChange(for: place, atMinute: at(7)) == .opens(at(9), tomorrow: false))
        #expect(engine.nextChange(for: place, atMinute: at(18)) == .opens(at(9), tomorrow: true))
        #expect(engine.nextChange(for: place, atMinute: at(7)).text(style: .twelveHour) == "Closed · opens at 9am")
    }

    @Test func twentyFourHourStyle() {
        #expect(TideChange.calmUntil(at(15, 30)).text(style: .twentyFourHour) == "Calm until 15:30")
    }

    @Test func spokenStatusForVoiceOver() {
        let narrative = TideNarrative(engine: engine, style: .twelveHour)
        let calm = makePlace(crowd: [15: 0.3, 16: 0.6, 17: 0.6, 18: 0.6])
        #expect(narrative.spokenStatus(for: calm, atMinute: at(14, 10)) == "calm until 3:30pm")
        let busy = makePlace(crowd: [12: 0.6, 13: 0.6, 14: 0.5, 15: 0.3])
        #expect(narrative.spokenStatus(for: busy, atMinute: at(12, 20)) == "busy now, calm from 3pm")
    }

    @Test func bannerExplainsTheChange() {
        let narrative = TideNarrative(engine: engine, style: .twelveHour)
        let place = makePlace(
            crowd: [15: 0.3, 16: 0.6, 17: 0.6, 18: 0.6],
            busyPeriods: [BusyPeriod(start: at(15, 30), end: at(17, 30), label: "the after-school rush")]
        )
        #expect(narrative.bannerDetail(for: place, atMinute: at(14, 10))
            == "Calm until about 3:30pm, then the after-school rush.")
    }
}

@Suite("Best time today")
struct BestWindowTests {
    let engine = TideEngine(profile: .standard)

    @Test func theLongestCalmWindowWins() {
        // Calm 14:10–15:30 (80 min), busy until 17:30, calm 17:30–19:00 (90 min).
        let place = makePlace(crowd: [15: 0.3, 16: 0.6, 17: 0.5, 18: 0.2])
        #expect(engine.bestWindow(for: place, atMinute: at(14, 10)) == TimeWindow(start: at(17, 30), end: at(19)))
    }

    @Test func aWindowCanStartNow() {
        let place = makePlace(crowd: [15: 0.3, 16: 0.6, 17: 0.6, 18: 0.6])
        let best = engine.bestWindow(for: place, atMinute: at(14, 10))
        #expect(best == TimeWindow(start: at(14, 10), end: at(15, 30)))
        let narrative = TideNarrative(engine: engine, style: .twelveHour)
        #expect(narrative.bestTimeLine(for: place, atMinute: at(14, 10)) == "Best time: now until 3:30pm")
    }

    @Test func tiesGoToTheEarlierWindow() {
        // Calm 9–11, busy 11–1, calm 1–3, busy until close: two 2-hour windows.
        let place = makePlace(
            close: at(17),
            crowd: [11: 0.6, 12: 0.8, 13: 0.1, 14: 0.1, 15: 0.6, 16: 0.6, 17: 0.6]
        )
        let windows = engine.calmWindows(for: place, from: at(9))
        #expect(windows == [TimeWindow(start: at(9), end: at(11)), TimeWindow(start: at(13), end: at(15))])
        #expect(engine.bestWindow(for: place, atMinute: at(9)) == windows.first)
    }

    @Test func windowsBeforeOpeningStartAtOpeningTime() {
        let place = makePlace(open: at(10), close: at(12))
        #expect(engine.bestWindow(for: place, atMinute: at(8)) == TimeWindow(start: at(10), end: at(12)))
    }

    @Test func noWindowWhenNothingIsCalm() {
        let place = makePlace(base: 0.75)
        #expect(engine.bestWindow(for: place, atMinute: at(10)) == nil)
        #expect(engine.bestWindow(for: makePlace(), atMinute: at(20)) == nil)
    }

    @Test func alertsFireAtTheNextCalmStart() {
        let place = makePlace(crowd: [15: 0.3, 16: 0.6, 17: 0.5, 18: 0.2])
        // Calm now, so the next calm window is the evening one.
        #expect(engine.nextCalmStart(for: place, atMinute: at(14, 10)) == at(17, 30))
        // Busy now, so the next calm window starts at 17:30 too.
        #expect(engine.nextCalmStart(for: place, atMinute: at(16)) == at(17, 30))
        #expect(engine.nextCalmStart(for: place, atMinute: at(18)) == nil)
    }

    @Test func goodMatchNeedsThreeCalmHours() {
        let place = makePlace(crowd: [17: 0.6])
        #expect(engine.isGoodMatch(place, atMinute: at(13)))
        #expect(!engine.isGoodMatch(place, atMinute: at(14, 30)))
        #expect(!engine.isGoodMatch(place, atMinute: at(20)))
    }
}

@Suite("Heads-up triggers")
struct TriggerTests {
    let place = makePlace(triggers: [
        Trigger(tag: .handDryer, label: "Hand dryer in toilets"),
        Trigger(tag: .stripLights, label: nil),
        Trigger(tag: .perfume, label: nil),
    ])

    @Test func triggersMapToFactors() {
        #expect(TriggerTag.handDryer.factor == .sudden)
        #expect(TriggerTag.music.factor == .noise)
        #expect(TriggerTag.coffeeGrinder.factor == .sudden)
        #expect(TriggerTag.stripLights.factor == .light)
        #expect(TriggerTag.bell.factor == .sudden)
        #expect(TriggerTag.perfume.factor == .smell)
    }

    @Test func aBitHidesTheHeadsUp() {
        var profile = SensoryProfile.standard
        for factor in Factor.allCases { profile[sensitivity: factor] = .mild }
        #expect(TideEngine(profile: profile).headsUp(for: place).isEmpty)
    }

    @Test func someAndALotShowTheHeadsUp() {
        var profile = SensoryProfile.standard
        profile.sudden = .strong
        profile.light = .moderate
        profile.smell = .mild
        let shown = TideEngine(profile: profile).headsUp(for: place).map(\.tag)
        #expect(shown == [.handDryer, .stripLights])
    }

    @Test func labelsFallBackToTheTagName() {
        #expect(place.triggers[0].text == "Hand dryer in toilets")
        #expect(place.triggers[1].text == "Strip lights")
    }
}

import Foundation
import Observation
import SwiftData

/// The latest check-in at a place, for "You checked in: Calm · 2:14pm".
struct CheckInSummary: Equatable {
    let feeling: CheckInFeeling
    let date: Date
    let decibels: Double?
}

/// Saved places and check-ins, kept on this iPhone with SwiftData.
@MainActor
@Observable
final class PersonalStore {
    private(set) var savedIDs: Set<String> = []
    private(set) var latestCheckIns: [String: CheckInSummary] = [:]

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        let saved = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
        savedIDs = Set(saved.map(\.placeID))

        let descriptor = FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.createdAt)])
        let checkIns = (try? context.fetch(descriptor)) ?? []
        var latest: [String: CheckInSummary] = [:]
        for checkIn in checkIns {
            guard let feeling = CheckInFeeling(rawValue: checkIn.feeling) else { continue }
            latest[checkIn.placeID] = CheckInSummary(feeling: feeling, date: checkIn.createdAt, decibels: checkIn.decibels)
        }
        latestCheckIns = latest
    }

    func isSaved(_ placeID: String) -> Bool {
        savedIDs.contains(placeID)
    }

    func toggleSaved(_ placeID: String) {
        if savedIDs.contains(placeID) {
            let saved = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
            for item in saved where item.placeID == placeID {
                context.delete(item)
            }
            savedIDs.remove(placeID)
        } else {
            context.insert(SavedPlace(placeID: placeID))
            savedIDs.insert(placeID)
        }
        try? context.save()
    }

    func addCheckIn(placeID: String, feeling: CheckInFeeling, noticed: Set<NoticedThing>, decibels: Double?, at date: Date) {
        let ordered = NoticedThing.allCases.filter(noticed.contains)
        context.insert(CheckIn(placeID: placeID, feeling: feeling, noticed: ordered, decibels: decibels, createdAt: date))
        try? context.save()
        latestCheckIns[placeID] = CheckInSummary(feeling: feeling, date: date, decibels: decibels)
    }
}

import Foundation

/// The user's Tide profile as a plain value. SwiftData persistence lives in `ProfileRecord`.
struct SensoryProfile: Equatable, Sendable {
    var sensitivities: [Factor: Sensitivity]
    var helps: Set<Help>
    var gentleAlerts: Bool
    var shareSoundReadings: Bool
    var trustedPerson: String

    init(
        sensitivities: [Factor: Sensitivity] = [:],
        helps: Set<Help> = [],
        gentleAlerts: Bool = false,
        shareSoundReadings: Bool = true,
        trustedPerson: String = ""
    ) {
        self.sensitivities = sensitivities
        self.helps = helps
        self.gentleAlerts = gentleAlerts
        self.shareSoundReadings = shareSoundReadings
        self.trustedPerson = trustedPerson
    }

    /// First-launch defaults: "Some" for everything, gentle alerts off, sound readings on.
    static let standard = SensoryProfile()

    subscript(factor: Factor) -> Sensitivity {
        get { sensitivities[factor] ?? .some }
        set { sensitivities[factor] = newValue }
    }

    /// The trusted person's name, or nil when the field is blank.
    var trustedPersonName: String? {
        let name = trustedPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

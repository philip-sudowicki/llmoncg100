import Foundation

// JSON decoding for the bundled sample data. Times are written as "HH:mm" strings.
// These conformances live in extensions so the models keep their memberwise initialisers.

/// The top level of `places.json`.
struct PlacesFile: Decodable, Sendable {
    let version: Int
    let places: [Place]
}

extension Place: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, category, street, offset, hours, forecast, triggers, goodToKnow, quietHour, busyPeriods, notes
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            category: try container.decode(PlaceCategory.self, forKey: .category),
            street: try container.decode(String.self, forKey: .street),
            offset: try container.decode(MetreOffset.self, forKey: .offset),
            hours: try container.decode(OpeningHours.self, forKey: .hours),
            forecast: try container.decode(HourlyForecast.self, forKey: .forecast),
            triggers: try container.decodeIfPresent([Trigger].self, forKey: .triggers) ?? [],
            goodToKnow: try container.decodeIfPresent([GoodToKnow].self, forKey: .goodToKnow) ?? [],
            quietHour: try container.decodeIfPresent(QuietHour.self, forKey: .quietHour),
            busyPeriods: try container.decodeIfPresent([BusyPeriod].self, forKey: .busyPeriods) ?? [],
            notes: try container.decodeIfPresent(FeelNotes.self, forKey: .notes) ?? FeelNotes()
        )
    }
}

extension OpeningHours: Decodable {
    private enum CodingKeys: String, CodingKey {
        case open, close
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let open = try container.decodeClockTime(forKey: .open)
        let close = try container.decodeClockTime(forKey: .close)
        guard close > open else {
            throw DecodingError.dataCorruptedError(
                forKey: .close, in: container, debugDescription: "Closing time must be after opening time."
            )
        }
        self.init(open: open, close: close)
    }
}

extension HourlyForecast: Decodable {
    private enum CodingKeys: String, CodingKey {
        case noiseDB, sudden, light, crowd, smell
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func series(_ key: CodingKeys) throws -> [Double] {
            let values = try container.decode([Double].self, forKey: key)
            guard values.count == Self.hoursPerDay else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: container, debugDescription: "Expected 24 hourly values, found \(values.count)."
                )
            }
            return values
        }
        self.init(
            noiseDB: try series(.noiseDB),
            sudden: try series(.sudden),
            light: try series(.light),
            crowd: try series(.crowd),
            smell: try series(.smell)
        )
    }
}

extension GoodToKnow: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, text
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        self.init(
            kind: Kind(rawValue: rawKind) ?? .info,
            text: try container.decode(String.self, forKey: .text)
        )
    }
}

extension QuietHour: Decodable {
    private enum CodingKeys: String, CodingKey {
        case days, start, end
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            days: try container.decode(String.self, forKey: .days),
            start: try container.decodeClockTime(forKey: .start),
            end: try container.decodeClockTime(forKey: .end)
        )
    }
}

extension BusyPeriod: Decodable {
    private enum CodingKeys: String, CodingKey {
        case start, end, label
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            start: try container.decodeClockTime(forKey: .start),
            end: try container.decodeClockTime(forKey: .end),
            label: try container.decode(String.self, forKey: .label)
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeClockTime(forKey key: Key) throws -> Int {
        let text = try decode(String.self, forKey: key)
        guard let minutes = ClockTime.minutes(from: text) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "Expected a time like \"09:30\", found \"\(text)\"."
            )
        }
        return minutes
    }
}

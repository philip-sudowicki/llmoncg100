import Foundation

/// Where places come from. v1 reads bundled JSON; a backend can replace it later.
protocol PlaceRepository: Sendable {
    func fetchPlaces() async throws -> [Place]
}

enum PlaceRepositoryError: Error, Equatable {
    case missingData
}

/// Reads `places.json` from the app bundle. No network access.
struct LocalPlaceRepository: PlaceRepository {
    let url: URL?

    init(url: URL? = Bundle.main.url(forResource: "places", withExtension: "json")) {
        self.url = url
    }

    func fetchPlaces() async throws -> [Place] {
        guard let url else { throw PlaceRepositoryError.missingData }
        return try Self.decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [Place] {
        try JSONDecoder().decode(PlacesFile.self, from: data).places
    }
}

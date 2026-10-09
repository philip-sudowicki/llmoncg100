import Foundation

/// Where places and their forecasts come from. v1 reads bundled JSON; a backend can replace it later.
protocol PlaceRepository: Sendable {
    func loadPlaces() async throws -> [Place]
}

enum PlaceRepositoryError: Error, Equatable {
    case missingResource(String)
    case duplicateID(String)
}

/// Reads `places.json` from the app bundle (or any file URL).
struct LocalPlaceRepository: PlaceRepository {
    let url: URL?
    private let resourceName: String

    init(bundle: Bundle = .main, resource: String = "places") {
        self.url = bundle.url(forResource: resource, withExtension: "json")
        self.resourceName = "\(resource).json"
    }

    init(url: URL) {
        self.url = url
        self.resourceName = url.lastPathComponent
    }

    func loadPlaces() async throws -> [Place] {
        try loadPlacesNow()
    }

    /// Synchronous load for previews and tests.
    func loadPlacesNow() throws -> [Place] {
        guard let url else { throw PlaceRepositoryError.missingResource(resourceName) }
        return try Self.decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [Place] {
        let file = try JSONDecoder().decode(PlacesFile.self, from: data)
        var seen = Set<String>()
        for place in file.places where !seen.insert(place.id).inserted {
            throw PlaceRepositoryError.duplicateID(place.id)
        }
        return file.places
    }

    private struct PlacesFile: Decodable {
        let version: Int
        let places: [Place]
    }
}

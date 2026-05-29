import Foundation

enum OrbitPathStoreError: LocalizedError {
    case missingOrbitPathFile(fileName: String)
    case invalidOrbitPathData(fileName: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .missingOrbitPathFile(let fileName):
            return "Missing bundled orbit path file: \(fileName)."
        case .invalidOrbitPathData(let fileName, let underlyingError):
            return "Could not decode orbit path file \(fileName): \(underlyingError.localizedDescription)"
        }
    }
}

final class OrbitPathStore {
    static let shared = OrbitPathStore()

    private init() {}

    func loadPlanetOrbitPaths() throws -> [OrbitPathDefinition] {
        let fileName = "planet_orbit_paths.json"
        let resourceName = "planet_orbit_paths"
        let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "OrbitPaths"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "Resources/OrbitPaths"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "json"
        )

        guard let url else {
            throw OrbitPathStoreError.missingOrbitPathFile(fileName: fileName)
        }

        do {
            let data = try Data(contentsOf: url)
            let codablePaths = try JSONDecoder().decode([CodableOrbitPathDefinition].self, from: data)
            return codablePaths.map(OrbitPathDefinition.init(codable:))
        } catch {
            throw OrbitPathStoreError.invalidOrbitPathData(fileName: fileName, underlyingError: error)
        }
    }
}

import Foundation

enum EphemerisSnapshotStoreError: LocalizedError {
    case missingSnapshotFile(presetID: String, fileName: String)
    case invalidSnapshotData(presetID: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .missingSnapshotFile(let presetID, let fileName):
            return "Missing bundled ephemeris snapshot for \(presetID): \(fileName)."
        case .invalidSnapshotData(let presetID, let underlyingError):
            return "Could not decode ephemeris snapshot for \(presetID): \(underlyingError.localizedDescription)"
        }
    }
}

final class EphemerisSnapshotStore {
    static let shared = EphemerisSnapshotStore()

    private init() {}

    func loadSnapshot(presetID: String) throws -> EphemerisSnapshot {
        let fileName = fileName(for: presetID)
        let resourceName = String(fileName.dropLast(5))

        let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "EphemerisSnapshots"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "Resources/EphemerisSnapshots"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "json"
        )

        guard let url else {
            throw EphemerisSnapshotStoreError.missingSnapshotFile(presetID: presetID, fileName: fileName)
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(EphemerisSnapshot.self, from: data)
        } catch {
            throw EphemerisSnapshotStoreError.invalidSnapshotData(presetID: presetID, underlyingError: error)
        }
    }

    private func fileName(for presetID: String) -> String {
        "ephemeris_\(presetID).json"
    }
}

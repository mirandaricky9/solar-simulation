import Foundation

struct CameraLockTarget: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: CelestialObjectKind
}

extension CelestialObjectKind {
    var sortOrder: Int {
        switch self {
        case .star:
            return 0
        case .planet:
            return 1
        case .moon:
            return 2
        case .dwarfPlanet:
            return 3
        case .comet:
            return 4
        case .asteroid:
            return 5
        case .asteroidBelt:
            return 6
        case .kuiperBelt:
            return 7
        case .oortCloud:
            return 8
        case .unknown:
            return 99
        }
    }
}

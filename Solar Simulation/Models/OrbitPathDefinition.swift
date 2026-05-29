import Foundation
import simd

nonisolated struct OrbitPathDefinition: Sendable {
    let objectName: String
    let pointsAU: [SIMD3<Float>]
    let kind: CelestialObjectKind
}

nonisolated struct CodableOrbitPathDefinition: Codable, Sendable {
    let objectName: String
    let kind: String
    let pointsAU: [[Float]]
}

nonisolated extension OrbitPathDefinition {
    init(codable: CodableOrbitPathDefinition) {
        self.objectName = codable.objectName
        self.kind = CelestialObjectKind(rawValue: codable.kind) ?? .unknown
        self.pointsAU = codable.pointsAU.compactMap { point in
            guard point.count >= 3 else { return nil }
            return SIMD3<Float>(point[0], point[1], point[2])
        }
    }
}

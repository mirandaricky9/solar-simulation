import Foundation
import simd

struct CelestialBody: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let mass: Double
    let visualRadius: Double
    let initialPosition: SIMD3<Double>
    let initialVelocity: SIMD3<Double>
    let kind: CelestialObjectKind
    let isStar: Bool
    let isMoon: Bool
    let isAsteroid: Bool
    let showsTrail: Bool
    let parentName: String?
    let orbitalRadius: Double?
    let orbitalSpeed: Double?
    let orbitalPeriodSeconds: Double?
    let color: SIMD4<Float>

    var position: SIMD3<Double>
    var velocity: SIMD3<Double>
    var cumulativePosition: [SIMD3<Double>] = []
    var orbitalPhase: Double?

    nonisolated var usesParentedOrbit: Bool {
        parentName != nil && orbitalRadius != nil && orbitalSpeed != nil && !isAsteroid
    }

    init(
        name: String,
        mass: Double,
        visualRadius: Double,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        color: SIMD4<Float>,
        kind: CelestialObjectKind? = nil,
        isStar: Bool = false,
        isMoon: Bool = false,
        isAsteroid: Bool = false,
        showsTrail: Bool = true,
        parentName: String? = nil,
        orbitalRadius: Double? = nil,
        orbitalSpeed: Double? = nil,
        orbitalPeriodSeconds: Double? = nil,
        orbitalPhase: Double? = nil
    ) {
        self.name = name
        self.mass = mass
        self.visualRadius = visualRadius
        self.initialPosition = position
        self.initialVelocity = velocity
        self.position = position
        self.velocity = velocity
        self.color = color
        self.kind = kind ?? Self.defaultKind(isStar: isStar, isMoon: isMoon, isAsteroid: isAsteroid)
        self.isStar = isStar
        self.isMoon = isMoon
        self.isAsteroid = isAsteroid
        self.showsTrail = showsTrail && !isAsteroid
        self.parentName = parentName
        self.orbitalRadius = orbitalRadius
        self.orbitalSpeed = orbitalSpeed
        self.orbitalPeriodSeconds = orbitalPeriodSeconds
        self.orbitalPhase = orbitalPhase
    }

    private static func defaultKind(isStar: Bool, isMoon: Bool, isAsteroid: Bool) -> CelestialObjectKind {
        if isStar {
            return .star
        }

        if isMoon {
            return .moon
        }

        if isAsteroid {
            return .asteroid
        }

        return .planet
    }
}

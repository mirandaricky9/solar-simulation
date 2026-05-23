import Foundation
import simd

enum ForceCalculator {
    static func calculateNetForce(for target: CelestialBody, dueTo bodies: [CelestialBody]) -> SIMD3<Double> {
        var netForce = SIMD3<Double>(0, 0, 0)

        for other in bodies {
            guard other.id != target.id else { continue }

            let rVector = other.position - target.position
            let distanceSquared = max(simd_length_squared(rVector), 1.0e12)
            let distance = sqrt(distanceSquared)

            let forceScale = SolarSystemConstants.G * target.mass * other.mass / (distanceSquared * distance)
            netForce += forceScale * rVector
        }

        return netForce
    }
}

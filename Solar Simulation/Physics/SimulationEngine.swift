import Foundation
import simd

nonisolated final class SimulationEngine {
    private var stepCounter = 0
    private let trailSampleInterval = 4
    private let maxTrailPoints = 1_000

    func reset() {
        stepCounter = 0
    }

    func step(bodies: inout [CelestialBody], dt: Double) {
        let snapshot = bodies
        let massiveIndices = snapshot.indices.filter { !snapshot[$0].isAsteroid }
        let asteroidIndices = snapshot.indices.filter { snapshot[$0].isAsteroid }
        var accelerations = Array(repeating: SIMD3<Double>(0, 0, 0), count: snapshot.count)

        for index in massiveIndices {
            for otherIndex in massiveIndices {
                guard otherIndex != index else { continue }
                accelerations[index] += acceleration(on: snapshot[index], from: snapshot[otherIndex])
            }
        }

        for index in asteroidIndices {
            for otherIndex in massiveIndices {
                accelerations[index] += acceleration(on: snapshot[index], from: snapshot[otherIndex])
            }
        }

        for index in bodies.indices {
            bodies[index].velocity += accelerations[index] * dt
            bodies[index].position += bodies[index].velocity * dt

            if bodies[index].isAsteroid {
                if !bodies[index].cumulativePosition.isEmpty {
                    bodies[index].cumulativePosition.removeAll(keepingCapacity: false)
                }
            } else if stepCounter % trailSampleInterval == 0 {
                bodies[index].cumulativePosition.append(bodies[index].position)

                if bodies[index].cumulativePosition.count > maxTrailPoints {
                    bodies[index].cumulativePosition.removeFirst(bodies[index].cumulativePosition.count - maxTrailPoints)
                }
            }
        }

        stepCounter += 1
    }

    private func acceleration(on target: CelestialBody, from other: CelestialBody) -> SIMD3<Double> {
        let rVector = other.position - target.position
        let distanceSquared = max(simd_length_squared(rVector), 1.0e12)
        let distance = sqrt(distanceSquared)
        let scale = SolarSystemConstants.G * other.mass / (distanceSquared * distance)

        return scale * rVector
    }
}

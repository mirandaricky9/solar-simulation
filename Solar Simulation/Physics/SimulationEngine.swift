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
        let parentedMoonIndices = snapshot.indices.filter { snapshot[$0].usesParentedOrbit }
        let massiveIndices = snapshot.indices.filter { !snapshot[$0].isAsteroid && !snapshot[$0].usesParentedOrbit }
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
            guard !snapshot[index].usesParentedOrbit else { continue }

            bodies[index].velocity += accelerations[index] * dt
            bodies[index].position += bodies[index].velocity * dt
        }

        updateParentedMoons(at: parentedMoonIndices, in: &bodies, dt: dt)
        updateTrails(for: &bodies)

        stepCounter += 1
    }

    private func updateParentedMoons(at indices: [Array<CelestialBody>.Index], in bodies: inout [CelestialBody], dt: Double) {
        guard !indices.isEmpty else { return }

        let parentIndexByName = Dictionary(uniqueKeysWithValues: bodies.indices.map { (bodies[$0].name, $0) })

        for index in indices {
            guard let parentName = bodies[index].parentName,
                  let orbitalRadius = bodies[index].orbitalRadius,
                  let orbitalSpeed = bodies[index].orbitalSpeed,
                  orbitalRadius > 0,
                  let parentIndex = parentIndexByName[parentName] else {
                continue
            }

            let parent = bodies[parentIndex]
            let currentOffset = bodies[index].position - parent.position
            var phase = bodies[index].orbitalPhase ?? atan2(currentOffset.y, currentOffset.x)
            phase = wrappedAngle(phase + (orbitalSpeed / orbitalRadius) * dt)

            let radialDirection = SIMD3<Double>(cos(phase), sin(phase), 0)
            let tangentialDirection = SIMD3<Double>(-sin(phase), cos(phase), 0)

            bodies[index].orbitalPhase = phase
            bodies[index].position = parent.position + radialDirection * orbitalRadius
            bodies[index].velocity = parent.velocity + tangentialDirection * orbitalSpeed
        }
    }

    private func updateTrails(for bodies: inout [CelestialBody]) {
        for index in bodies.indices {
            if !bodies[index].showsTrail {
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
    }

    private func acceleration(on target: CelestialBody, from other: CelestialBody) -> SIMD3<Double> {
        let rVector = other.position - target.position
        let distanceSquared = max(simd_length_squared(rVector), 1.0e12)
        let distance = sqrt(distanceSquared)
        let scale = SolarSystemConstants.G * other.mass / (distanceSquared * distance)

        return scale * rVector
    }

    private func wrappedAngle(_ angle: Double) -> Double {
        let period = Double.pi * 2
        var result = angle.truncatingRemainder(dividingBy: period)

        if result > Double.pi {
            result -= period
        } else if result < -Double.pi {
            result += period
        }

        return result
    }
}

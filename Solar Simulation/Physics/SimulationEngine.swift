import Foundation
import simd

final class SimulationEngine {
    func step(bodies: inout [CelestialBody], dt: Double) {
        let snapshot = bodies
        var accelerations: [SIMD3<Double>] = []
        accelerations.reserveCapacity(snapshot.count)

        for body in snapshot {
            let force = ForceCalculator.calculateNetForce(for: body, dueTo: snapshot)
            accelerations.append(force / body.mass)
        }

        for index in bodies.indices {
            bodies[index].velocity += accelerations[index] * dt
            bodies[index].position += bodies[index].velocity * dt
            bodies[index].cumulativePosition.append(bodies[index].position)

            if bodies[index].cumulativePosition.count > 2_000 {
                bodies[index].cumulativePosition.removeFirst(bodies[index].cumulativePosition.count - 2_000)
            }
        }
    }
}

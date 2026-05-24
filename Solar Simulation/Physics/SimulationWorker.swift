import Foundation

actor SimulationWorker {
    private var bodies: [CelestialBody] = []
    private let engine = SimulationEngine()

    func setBodies(_ newBodies: [CelestialBody]) {
        bodies = newBodies
        engine.reset()
    }

    func advance(dt: Double) {
        engine.step(bodies: &bodies, dt: dt)
    }

    func step(dt: Double) -> [CelestialBody] {
        engine.step(bodies: &bodies, dt: dt)
        return bodies
    }

    func snapshot() -> [CelestialBody] {
        bodies
    }
}

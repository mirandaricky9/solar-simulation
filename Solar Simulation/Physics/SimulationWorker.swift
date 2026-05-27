import Foundation

actor SimulationWorker {
    private var bodies: [CelestialBody] = []
    private let engine = SimulationEngine()

    func setBodies(_ newBodies: [CelestialBody]) {
        bodies = newBodies
        engine.reset()
    }

    func advance(dt: Double) {
        advanceWithoutSnapshot(substeps: 1, dt: dt)
    }

    func step(dt: Double) -> [CelestialBody] {
        advanceAndSnapshot(substeps: 1, dt: dt)
    }

    func advanceWithoutSnapshot(substeps: Int, dt: Double) {
        runSubsteps(substeps, dt: dt)
    }

    func advanceAndSnapshot(substeps: Int, dt: Double) -> [CelestialBody] {
        runSubsteps(substeps, dt: dt)
        return bodies
    }

    private func runSubsteps(_ substeps: Int, dt: Double) {
        guard substeps > 0, dt.isFinite, dt > 0 else {
            return
        }

        for _ in 0..<substeps {
            engine.step(bodies: &bodies, dt: dt)
        }
    }

    func snapshot() -> [CelestialBody] {
        bodies
    }

    func clearTrails() -> [CelestialBody] {
        for index in bodies.indices {
            bodies[index].cumulativePosition.removeAll(keepingCapacity: true)
        }

        return bodies
    }
}

import Combine
import Foundation
import simd
import SwiftUI

@MainActor
final class SimulationViewModel: ObservableObject {
    @Published private(set) var bodies: [CelestialBody] = []
    @Published var isRunning = false
    @Published var currentTime: Double = 0
    @Published var timeStepMultiplier: Double = 24
    @Published var showAsteroidBelt = true
    @Published private(set) var cameraResetRequestID = 0

    private let simulationWorker = SimulationWorker()
    private var simulationTask: Task<Void, Never>?
    private var workerSyncTask: Task<Void, Never>?
    private var accumulatedTime: Double = 0
    private let simulationFrameIntervalNanoseconds: UInt64 = 16_666_667
    private let publishedSnapshotInterval = 2

    init() {
        reset()
    }

    deinit {
        simulationTask?.cancel()
        workerSyncTask?.cancel()
    }

    func reset() {
        simulationTask?.cancel()
        simulationTask = nil
        workerSyncTask?.cancel()
        isRunning = false
        currentTime = 0
        accumulatedTime = 0

        let newBodies = Self.makeInitialBodies(includeAsteroids: showAsteroidBelt)
        bodies = newBodies
        cameraResetRequestID += 1

        workerSyncTask = Task { [simulationWorker] in
            await simulationWorker.setBodies(newBodies)
        }
    }

    func toggleSimulation() {
        if isRunning {
            stopSimulationLoop()
        } else {
            isRunning = true
            startSimulationLoop()
        }
    }

    func simulateStep() {
        let dt = SolarSystemConstants.baseTimeStep * timeStepMultiplier

        Task { [simulationWorker] in
            let steppedBodies = await simulationWorker.step(dt: dt)

            await MainActor.run {
                self.accumulatedTime += dt
                self.currentTime = self.accumulatedTime
                self.bodies = steppedBodies
            }
        }
    }

    private func startSimulationLoop() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            var stepIndex = 0

            while !Task.isCancelled {
                guard let self else { return }

                let dt = SolarSystemConstants.baseTimeStep * self.timeStepMultiplier
                let shouldPublish = stepIndex % self.publishedSnapshotInterval == 0

                if shouldPublish {
                    let steppedBodies = await self.simulationWorker.step(dt: dt)
                    guard !Task.isCancelled else { return }
                    self.accumulatedTime += dt
                    self.currentTime = self.accumulatedTime
                    self.bodies = steppedBodies
                } else {
                    await self.simulationWorker.advance(dt: dt)
                    guard !Task.isCancelled else { return }
                    self.accumulatedTime += dt
                }

                stepIndex += 1
                try? await Task.sleep(nanoseconds: self.simulationFrameIntervalNanoseconds)
            }
        }
    }

    private func stopSimulationLoop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
    }

    static func makeInitialBodies(includeAsteroids: Bool) -> [CelestialBody] {
        var result: [CelestialBody] = []
        let au = SolarSystemConstants.astronomicalUnit

        result.append(
            CelestialBody(
                name: "Sun",
                mass: SolarSystemConstants.solarMass,
                visualRadius: 696_340_000,
                position: SIMD3<Double>(0, 0, 0),
                velocity: SIMD3<Double>(0, 0, 0),
                color: SIMD4<Float>(1.0, 0.78, 0.18, 1.0),
                isStar: true
            )
        )

        func addPlanet(
            name: String,
            mass: Double,
            radius: Double,
            orbitalRadiusAU: Double,
            orbitalSpeed: Double,
            color: SIMD4<Float>
        ) {
            result.append(
                CelestialBody(
                    name: name,
                    mass: mass,
                    visualRadius: radius,
                    position: SIMD3<Double>(orbitalRadiusAU * au, 0, 0),
                    velocity: SIMD3<Double>(0, orbitalSpeed, 0),
                    color: color
                )
            )
        }

        addPlanet(name: "Mercury", mass: 3.3011e23, radius: 2_439_700, orbitalRadiusAU: 0.387, orbitalSpeed: 47_360, color: SIMD4<Float>(0.55, 0.52, 0.48, 1))
        addPlanet(name: "Venus", mass: 4.8675e24, radius: 6_051_800, orbitalRadiusAU: 0.723, orbitalSpeed: 35_020, color: SIMD4<Float>(0.95, 0.76, 0.46, 1))
        addPlanet(name: "Earth", mass: 5.972e24, radius: 6_371_000, orbitalRadiusAU: 1.0, orbitalSpeed: 29_780, color: SIMD4<Float>(0.10, 0.35, 1.0, 1))
        addPlanet(name: "Mars", mass: 6.4171e23, radius: 3_389_500, orbitalRadiusAU: 1.524, orbitalSpeed: 24_077, color: SIMD4<Float>(0.90, 0.25, 0.10, 1))
        addPlanet(name: "Jupiter", mass: 1.8982e27, radius: 69_911_000, orbitalRadiusAU: 5.203, orbitalSpeed: 13_070, color: SIMD4<Float>(0.85, 0.65, 0.45, 1))
        addPlanet(name: "Saturn", mass: 5.6834e26, radius: 58_232_000, orbitalRadiusAU: 9.537, orbitalSpeed: 9_680, color: SIMD4<Float>(0.90, 0.78, 0.55, 1))
        addPlanet(name: "Uranus", mass: 8.6810e25, radius: 25_362_000, orbitalRadiusAU: 19.191, orbitalSpeed: 6_800, color: SIMD4<Float>(0.55, 0.85, 0.90, 1))
        addPlanet(name: "Neptune", mass: 1.02413e26, radius: 24_622_000, orbitalRadiusAU: 30.07, orbitalSpeed: 5_430, color: SIMD4<Float>(0.20, 0.35, 0.90, 1))

        let earthPosition = SIMD3<Double>(au, 0, 0)
        let earthVelocity = SIMD3<Double>(0, 29_780, 0)
        result.append(
            CelestialBody(
                name: "Moon",
                mass: 7.342e22,
                visualRadius: 1_737_400,
                position: earthPosition + SIMD3<Double>(384_400_000, 0, 0),
                velocity: earthVelocity + SIMD3<Double>(0, 1_022, 0),
                color: SIMD4<Float>(0.75, 0.75, 0.72, 1),
                isMoon: true
            )
        )

        if includeAsteroids {
            let asteroidCount = 600
            for index in 0..<asteroidCount {
                let angle = Double(index) / Double(asteroidCount) * Double.pi * 2
                let orbitalRadiusAU = Double.random(in: 2.2...3.2)
                let orbitalRadius = orbitalRadiusAU * au
                let z = Double.random(in: -0.03...0.03) * au

                let position = SIMD3<Double>(
                    cos(angle) * orbitalRadius,
                    sin(angle) * orbitalRadius,
                    z
                )

                let speed = sqrt(SolarSystemConstants.G * SolarSystemConstants.solarMass / orbitalRadius)
                let velocity = SIMD3<Double>(
                    -sin(angle) * speed,
                    cos(angle) * speed,
                    0
                )

                result.append(
                    CelestialBody(
                        name: "Asteroid \(index)",
                        mass: 1.0e15,
                        visualRadius: Double.random(in: 50_000...200_000),
                        position: position,
                        velocity: velocity,
                        color: SIMD4<Float>(0.45, 0.42, 0.38, 1),
                        isAsteroid: true
                    )
                )
            }
        }

        return result
    }
}

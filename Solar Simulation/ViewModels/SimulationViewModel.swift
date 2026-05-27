import Combine
import Foundation
import simd
import SwiftUI

@MainActor
final class SimulationViewModel: ObservableObject {
    @Published private(set) var bodies: [CelestialBody] = []
    @Published var isRunning = false
    @Published var currentTime: Double = 0
    @Published var simulatedDaysPerSecond: Double = 10
    @Published var directTimeStepMultiplier: Double = 1
    @Published var cameraSensitivity: Double = 1.0
    @Published var showAsteroidBelt = true
    @Published var showComets = true
    @Published var showLiveTrails = true
    @Published var showPretracedOrbitPaths = true
    @Published var selectedObjectInfo: SelectedObjectInfo?
    @Published private(set) var cameraResetRequestID = 0
    @Published private(set) var asteroidField = AsteroidField(count: 0)
    let cometField = CometVisualField()

    private let simulationWorker = SimulationWorker()
    private var simulationTask: Task<Void, Never>?
    private var workerSyncTask: Task<Void, Never>?
    private var accumulatedTime: Double = 0
    private var accumulatedSimulationDebt: Double = 0
    private var lastFrameTime: CFTimeInterval?
    private var selectedObjectName: String?
    private let fixedPhysicsStepSeconds: Double = 3_600
    private let maxSubstepsPerFrame = 32
    private let simulationFrameIntervalNanoseconds: UInt64 = 16_666_667
    private let publishedSnapshotInterval = 2
    private let defaultAsteroidVisualCount = 8_000
    private let asteroidBeltSelectionID = UUID(uuidString: "D78A4AF8-711E-4B56-9E33-5AFD02909346")!

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
        accumulatedSimulationDebt = 0
        lastFrameTime = nil

        asteroidField = AsteroidField(count: showAsteroidBelt ? defaultAsteroidVisualCount : 0)

        let newBodies = Self.makeInitialBodies()
        bodies = newBodies
        updateSelectedObjectInfo()
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
        let dt = directPhysicsStepSeconds

        Task { [simulationWorker] in
            let steppedBodies = await simulationWorker.step(dt: dt)

            await MainActor.run {
                self.accumulatedTime += dt
                self.currentTime = self.accumulatedTime
                self.bodies = steppedBodies
                self.updateSelectedObjectInfo()
            }
        }
    }

    func clearTrails() {
        Task { [simulationWorker] in
            let updatedBodies = await simulationWorker.clearTrails()

            await MainActor.run {
                self.bodies = updatedBodies
                self.updateSelectedObjectInfo()
            }
        }
    }

    func selectObject(named name: String) {
        selectedObjectName = name
        updateSelectedObjectInfo()
    }

    func clearSelection() {
        selectedObjectName = nil
        selectedObjectInfo = nil
    }

    func updateSelectedObjectInfo() {
        guard let selectedObjectName else { return }

        if let body = bodies.first(where: { $0.name == selectedObjectName }) {
            selectedObjectInfo = makeSelectedInfo(for: body, bodies: bodies)
            return
        }

        if let comet = cometField.definitions.first(where: { $0.name == selectedObjectName || $0.shortName == selectedObjectName }) {
            selectedObjectInfo = makeSelectedInfo(for: comet, simulationTime: currentTime)
            return
        }

        if selectedObjectName == "Asteroid Belt" {
            selectedObjectInfo = makeAsteroidBeltInfo()
            return
        }

        selectedObjectInfo = nil
    }

    private func startSimulationLoop() {
        simulationTask?.cancel()
        accumulatedSimulationDebt = 0
        lastFrameTime = nil

        simulationTask = Task { [weak self] in
            var stepIndex = 0

            while !Task.isCancelled {
                guard let self else { return }

                let now = CFAbsoluteTimeGetCurrent()
                let realDelta = self.lastFrameTime.map { max(0, now - $0) } ?? 0
                self.lastFrameTime = now

                let dt = self.fixedPhysicsStepSeconds
                let physicsStepDt = self.directPhysicsStepSeconds
                self.accumulatedSimulationDebt += realDelta * self.simulatedSecondsPerRealSecond

                var substeps = 0
                while self.accumulatedSimulationDebt >= dt && substeps < self.maxSubstepsPerFrame {
                    self.accumulatedSimulationDebt -= dt
                    substeps += 1
                }

                if substeps == self.maxSubstepsPerFrame {
                    self.accumulatedSimulationDebt = min(
                        self.accumulatedSimulationDebt,
                        dt * Double(self.maxSubstepsPerFrame)
                    )
                }

                let shouldPublish = stepIndex % self.publishedSnapshotInterval == 0

                if substeps > 0 {
                    let simulatedTimeAdvanced = Double(substeps) * physicsStepDt

                    if shouldPublish {
                        let steppedBodies = await self.simulationWorker.advanceAndSnapshot(
                            substeps: substeps,
                            dt: physicsStepDt
                        )
                        guard !Task.isCancelled else { return }
                        self.accumulatedTime += simulatedTimeAdvanced
                        self.currentTime = self.accumulatedTime
                        self.bodies = steppedBodies
                        self.updateSelectedObjectInfo()
                    } else {
                        await self.simulationWorker.advanceWithoutSnapshot(
                            substeps: substeps,
                            dt: physicsStepDt
                        )
                        guard !Task.isCancelled else { return }
                        self.accumulatedTime += simulatedTimeAdvanced
                    }

                    stepIndex += 1
                }

                try? await Task.sleep(nanoseconds: self.simulationFrameIntervalNanoseconds)
            }
        }
    }

    private func stopSimulationLoop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
        lastFrameTime = nil
    }

    private func makeSelectedInfo(for body: CelestialBody, bodies: [CelestialBody]) -> SelectedObjectInfo {
        let sun = bodies.first(where: \.isStar)
        let parent = body.parentName.flatMap { parentName in
            bodies.first(where: { $0.name == parentName })
        }
        let distanceToSun = sun.map { simd_length(body.position - $0.position) }
        let distanceToParent = parent.map { simd_length(body.position - $0.position) }
        let speed = simd_length(body.velocity)
        let circumference = 2 * Double.pi * body.visualRadius
        let orbitalPeriod = body.orbitalPeriodSeconds
            ?? body.orbitalRadius.flatMap { radius in
                guard let orbitalSpeed = body.orbitalSpeed, orbitalSpeed > 0 else { return nil }
                return 2 * Double.pi * radius / orbitalSpeed
            }
            ?? estimateOrbitalPeriod(distanceMeters: distanceToParent ?? distanceToSun, speedMetersPerSecond: speed)

        return SelectedObjectInfo(
            id: body.id,
            name: body.name,
            kind: body.kind,
            parentName: body.parentName,
            massKg: body.mass,
            radiusMeters: body.visualRadius,
            circumferenceMeters: circumference,
            distanceToSunMeters: body.isStar ? nil : distanceToSun,
            distanceToParentMeters: distanceToParent,
            orbitalPeriodSeconds: body.isStar ? nil : orbitalPeriod,
            speedMetersPerSecond: speed,
            apsisPhase: apsisPhase(for: body, primary: parent ?? sun),
            notes: nil
        )
    }

    private func makeSelectedInfo(for comet: CometDefinition, simulationTime: Double) -> SelectedObjectInfo {
        let positionAU = KeplerOrbitSolver.positionAU(definition: comet, simulationTime: simulationTime)
        let futurePositionAU = KeplerOrbitSolver.positionAU(definition: comet, simulationTime: simulationTime + 3_600)
        let distanceToSun = Double(simd_length(positionAU)) * SolarSystemConstants.astronomicalUnit
        let futureDistanceToSun = Double(simd_length(futurePositionAU)) * SolarSystemConstants.astronomicalUnit
        let radius = Double(comet.nucleusRadiusAU) * SolarSystemConstants.astronomicalUnit
        let orbitalPeriod = SolarSystemConstants.yearsToSeconds(comet.periodYears)
        let speed = cometSpeed(distanceMeters: distanceToSun, semiMajorAxisAU: comet.semiMajorAxisAU)
        let apsisPhase: ApsisPhase

        if abs(futureDistanceToSun - distanceToSun) < 1_000 {
            apsisPhase = .unknown
        } else {
            apsisPhase = futureDistanceToSun > distanceToSun ? .movingTowardAphelion : .movingTowardPerihelion
        }

        return SelectedObjectInfo(
            id: comet.id,
            name: comet.name,
            kind: .comet,
            parentName: "Sun",
            massKg: nil,
            radiusMeters: radius,
            circumferenceMeters: 2 * Double.pi * radius,
            distanceToSunMeters: distanceToSun,
            distanceToParentMeters: nil,
            orbitalPeriodSeconds: orbitalPeriod,
            speedMetersPerSecond: speed,
            apsisPhase: apsisPhase,
            notes: "Analytic visual comet; not N-body simulated."
        )
    }

    private func makeAsteroidBeltInfo() -> SelectedObjectInfo {
        SelectedObjectInfo(
            id: asteroidBeltSelectionID,
            name: "Asteroid Belt",
            kind: .asteroidBelt,
            parentName: "Sun",
            massKg: nil,
            radiusMeters: nil,
            circumferenceMeters: nil,
            distanceToSunMeters: 2.7 * SolarSystemConstants.astronomicalUnit,
            distanceToParentMeters: nil,
            orbitalPeriodSeconds: nil,
            speedMetersPerSecond: nil,
            apsisPhase: .notApplicable,
            notes: "Aesthetic asteroid field; not N-body simulated. Individual asteroids use analytic visual orbits."
        )
    }

    private func estimateOrbitalPeriod(distanceMeters: Double?, speedMetersPerSecond: Double) -> Double? {
        guard let distanceMeters, speedMetersPerSecond > 0 else { return nil }
        return 2 * Double.pi * distanceMeters / speedMetersPerSecond
    }

    private func cometSpeed(distanceMeters: Double, semiMajorAxisAU: Double) -> Double? {
        let semiMajorAxisMeters = semiMajorAxisAU * SolarSystemConstants.astronomicalUnit
        guard distanceMeters > 0, semiMajorAxisMeters > 0 else { return nil }

        let mu = SolarSystemConstants.G * SolarSystemConstants.solarMass
        let speedSquared = mu * (2 / distanceMeters - 1 / semiMajorAxisMeters)
        guard speedSquared.isFinite, speedSquared > 0 else { return nil }

        return sqrt(speedSquared)
    }

    private func apsisPhase(for body: CelestialBody, primary: CelestialBody?) -> ApsisPhase {
        guard !body.isStar, let primary else { return .notApplicable }

        let relativePosition = body.position - primary.position
        let distance = simd_length(relativePosition)
        guard distance > 0 else { return .unknown }

        let relativeVelocity = body.velocity - primary.velocity
        let radialVelocity = simd_dot(relativePosition, relativeVelocity) / distance
        let threshold = 1.0

        if abs(radialVelocity) <= threshold {
            return .unknown
        }

        if body.isMoon {
            if body.parentName == "Earth" && body.name == "Moon" {
                return radialVelocity > 0 ? .movingTowardApogee : .movingTowardPerigee
            }

            return radialVelocity > 0 ? .movingTowardApoapsis : .movingTowardPeriapsis
        }

        return radialVelocity > 0 ? .movingTowardAphelion : .movingTowardPerihelion
    }

    private var simulatedSecondsPerRealSecond: Double {
        simulatedDaysPerSecond * 86_400
    }

    private var directPhysicsStepSeconds: Double {
        fixedPhysicsStepSeconds * directTimeStepMultiplier
    }

    static func makeInitialBodies() -> [CelestialBody] {
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
                isStar: true,
                showsTrail: false
            )
        )

        @discardableResult
        func addPlanet(
            name: String,
            mass: Double,
            radius: Double,
            orbitalRadiusAU: Double,
            orbitalSpeed: Double,
            color: SIMD4<Float>
        ) -> (position: SIMD3<Double>, velocity: SIMD3<Double>) {
            let position = SIMD3<Double>(orbitalRadiusAU * au, 0, 0)
            let velocity = SIMD3<Double>(0, orbitalSpeed, 0)

            result.append(
                CelestialBody(
                    name: name,
                    mass: mass,
                    visualRadius: radius,
                    position: position,
                    velocity: velocity,
                    color: color,
                    orbitalPeriodSeconds: SolarSystemConstants.siderealOrbitalPeriodSeconds(forPlanetNamed: name)
                )
            )

            return (position, velocity)
        }

        addPlanet(name: "Mercury", mass: 3.3011e23, radius: 2_439_700, orbitalRadiusAU: 0.387, orbitalSpeed: 47_360, color: SIMD4<Float>(0.55, 0.52, 0.48, 1))
        addPlanet(name: "Venus", mass: 4.8675e24, radius: 6_051_800, orbitalRadiusAU: 0.723, orbitalSpeed: 35_020, color: SIMD4<Float>(0.95, 0.76, 0.46, 1))
        let earth = addPlanet(name: "Earth", mass: 5.972e24, radius: 6_371_000, orbitalRadiusAU: 1.0, orbitalSpeed: 29_780, color: SIMD4<Float>(0.10, 0.35, 1.0, 1))
        let mars = addPlanet(name: "Mars", mass: 6.4171e23, radius: 3_389_500, orbitalRadiusAU: 1.524, orbitalSpeed: 24_077, color: SIMD4<Float>(0.90, 0.25, 0.10, 1))
        let jupiter = addPlanet(name: "Jupiter", mass: 1.8982e27, radius: 69_911_000, orbitalRadiusAU: 5.203, orbitalSpeed: 13_070, color: SIMD4<Float>(0.85, 0.65, 0.45, 1))
        let saturn = addPlanet(name: "Saturn", mass: 5.6834e26, radius: 58_232_000, orbitalRadiusAU: 9.537, orbitalSpeed: 9_680, color: SIMD4<Float>(0.90, 0.78, 0.55, 1))
        let uranus = addPlanet(name: "Uranus", mass: 8.6810e25, radius: 25_362_000, orbitalRadiusAU: 19.191, orbitalSpeed: 6_800, color: SIMD4<Float>(0.55, 0.85, 0.90, 1))
        let neptune = addPlanet(name: "Neptune", mass: 1.02413e26, radius: 24_622_000, orbitalRadiusAU: 30.07, orbitalSpeed: 5_430, color: SIMD4<Float>(0.20, 0.35, 0.90, 1))

        addMoon(&result, name: "Moon", parentName: "Earth", parentPosition: earth.position, parentVelocity: earth.velocity, mass: 7.342e22, radius: 1_737_400, distanceFromParent: 384_400_000, orbitalSpeed: 1_022, color: SIMD4<Float>(0.75, 0.75, 0.72, 1), showsTrail: true)

        addMoon(&result, name: "Phobos", parentName: "Mars", parentPosition: mars.position, parentVelocity: mars.velocity, mass: 1.0659e16, radius: 11_266, distanceFromParent: 9_376_000, orbitalSpeed: 2_138, color: SIMD4<Float>(0.58, 0.50, 0.44, 1))
        addMoon(&result, name: "Deimos", parentName: "Mars", parentPosition: mars.position, parentVelocity: mars.velocity, mass: 1.4762e15, radius: 6_200, distanceFromParent: 23_463_000, orbitalSpeed: 1_351, color: SIMD4<Float>(0.54, 0.49, 0.44, 1))

        addMoon(&result, name: "Io", parentName: "Jupiter", parentPosition: jupiter.position, parentVelocity: jupiter.velocity, mass: 8.9319e22, radius: 1_821_600, distanceFromParent: 421_700_000, orbitalSpeed: 17_334, color: SIMD4<Float>(0.95, 0.78, 0.30, 1))
        addMoon(&result, name: "Europa", parentName: "Jupiter", parentPosition: jupiter.position, parentVelocity: jupiter.velocity, mass: 4.7998e22, radius: 1_560_800, distanceFromParent: 671_100_000, orbitalSpeed: 13_740, color: SIMD4<Float>(0.82, 0.76, 0.65, 1))
        addMoon(&result, name: "Ganymede", parentName: "Jupiter", parentPosition: jupiter.position, parentVelocity: jupiter.velocity, mass: 1.4819e23, radius: 2_634_100, distanceFromParent: 1_070_400_000, orbitalSpeed: 10_880, color: SIMD4<Float>(0.62, 0.56, 0.48, 1))
        addMoon(&result, name: "Callisto", parentName: "Jupiter", parentPosition: jupiter.position, parentVelocity: jupiter.velocity, mass: 1.0759e23, radius: 2_410_300, distanceFromParent: 1_882_700_000, orbitalSpeed: 8_204, color: SIMD4<Float>(0.42, 0.39, 0.34, 1))

        addMoon(&result, name: "Mimas", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 3.7493e19, radius: 198_200, distanceFromParent: 185_539_000, orbitalSpeed: 14_280, color: SIMD4<Float>(0.72, 0.68, 0.60, 1))
        addMoon(&result, name: "Enceladus", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.0802e20, radius: 252_100, distanceFromParent: 238_042_000, orbitalSpeed: 12_640, color: SIMD4<Float>(0.88, 0.90, 0.86, 1))
        addMoon(&result, name: "Tethys", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 6.1745e20, radius: 531_100, distanceFromParent: 294_672_000, orbitalSpeed: 11_350, color: SIMD4<Float>(0.76, 0.74, 0.68, 1))
        addMoon(&result, name: "Dione", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.0955e21, radius: 561_400, distanceFromParent: 377_415_000, orbitalSpeed: 10_030, color: SIMD4<Float>(0.70, 0.70, 0.66, 1))
        addMoon(&result, name: "Rhea", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 2.3065e21, radius: 763_800, distanceFromParent: 527_108_000, orbitalSpeed: 8_480, color: SIMD4<Float>(0.68, 0.67, 0.62, 1))
        addMoon(&result, name: "Titan", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.3452e23, radius: 2_574_700, distanceFromParent: 1_221_870_000, orbitalSpeed: 5_570, color: SIMD4<Float>(0.85, 0.58, 0.30, 1))
        addMoon(&result, name: "Iapetus", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.8056e21, radius: 734_500, distanceFromParent: 3_560_820_000, orbitalSpeed: 3_260, color: SIMD4<Float>(0.60, 0.56, 0.50, 1))

        addMoon(&result, name: "Miranda", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 6.59e19, radius: 235_800, distanceFromParent: 129_390_000, orbitalSpeed: 6_680, color: SIMD4<Float>(0.62, 0.65, 0.62, 1))
        addMoon(&result, name: "Ariel", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 1.353e21, radius: 578_900, distanceFromParent: 191_020_000, orbitalSpeed: 5_510, color: SIMD4<Float>(0.68, 0.70, 0.68, 1))
        addMoon(&result, name: "Umbriel", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 1.172e21, radius: 584_700, distanceFromParent: 266_300_000, orbitalSpeed: 4_670, color: SIMD4<Float>(0.45, 0.46, 0.45, 1))
        addMoon(&result, name: "Titania", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 3.527e21, radius: 788_900, distanceFromParent: 435_910_000, orbitalSpeed: 3_640, color: SIMD4<Float>(0.64, 0.66, 0.62, 1))
        addMoon(&result, name: "Oberon", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 3.014e21, radius: 761_400, distanceFromParent: 583_520_000, orbitalSpeed: 3_150, color: SIMD4<Float>(0.55, 0.54, 0.50, 1))

        addMoon(&result, name: "Triton", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 2.14e22, radius: 1_353_400, distanceFromParent: 354_759_000, orbitalSpeed: 4_390, color: SIMD4<Float>(0.72, 0.70, 0.66, 1))
        addMoon(&result, name: "Nereid", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 3.1e19, radius: 170_000, distanceFromParent: 5_513_400_000, orbitalSpeed: 950, color: SIMD4<Float>(0.50, 0.50, 0.48, 1))

        // TODO: Render tiny irregular moons as particles or orbit markers instead of full N-body bodies.

        return result
    }

    private static func addMoon(
        _ result: inout [CelestialBody],
        name: String,
        parentName: String,
        parentPosition: SIMD3<Double>,
        parentVelocity: SIMD3<Double>,
        mass: Double,
        radius: Double,
        distanceFromParent: Double,
        orbitalSpeed: Double,
        color: SIMD4<Float>,
        showsTrail: Bool = false
    ) {
        let angle = deterministicMoonAngle(name: name, sequence: result.count)
        let radialDirection = SIMD3<Double>(cos(angle), sin(angle), 0)
        let tangentialDirection = SIMD3<Double>(-sin(angle), cos(angle), 0)

        result.append(
            CelestialBody(
                name: name,
                mass: mass,
                visualRadius: radius,
                position: parentPosition + radialDirection * distanceFromParent,
                velocity: parentVelocity + tangentialDirection * orbitalSpeed,
                color: color,
                isMoon: true,
                showsTrail: showsTrail,
                parentName: parentName,
                orbitalRadius: distanceFromParent,
                orbitalSpeed: orbitalSpeed,
                orbitalPeriodSeconds: 2 * Double.pi * distanceFromParent / orbitalSpeed,
                orbitalPhase: angle
            )
        )
    }

    private static func deterministicMoonAngle(name: String, sequence: Int) -> Double {
        let scalarSum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (Double(sequence) * 2.399963229728653 + Double(scalarSum) * 0.013).truncatingRemainder(dividingBy: Double.pi * 2)
    }
}

import Combine
import Foundation
import simd
import SwiftUI

@MainActor
final class SimulationViewModel: ObservableObject {
    @Published private(set) var bodies: [CelestialBody] = []
    @Published var isRunning = false
    @Published var currentTime: Double = 0
    @Published var selectedEphemerisPresetID: String = "current_2026"
    @Published var currentSimulationDate: Date = EphemerisPresetCatalog.noonUTCDate(for: "current_2026") ?? Date(timeIntervalSince1970: 0)
    @Published var currentSimulationDateText: String = "2026-05-28"
    @Published var ephemerisLoadError: String?
    @Published var simulatedDaysPerSecond: Double = 10
    @Published var directTimeStepMultiplier: Double = 1
    @Published var cameraSensitivity: Double = 1.0
    @Published var showAsteroidBelt = true {
        didSet { validateCameraLockTarget() }
    }
    @Published var showComets = true {
        didSet { validateCameraLockTarget() }
    }
    @Published var showDwarfPlanets = true {
        didSet { validateCameraLockTarget() }
    }
    @Published var showNotableAsteroids = true {
        didSet { validateCameraLockTarget() }
    }
    @Published var showLiveTrails = true
    @Published var showPretracedOrbitPaths = true
    @Published var visiblePlanetNames: Set<String> = Set(PlanetFactCatalog.planetNames)
    @Published var requestedCameraTargetName: String?
    @Published var requestedCameraPreset: CameraPreset?
    @Published var cameraLockTargetName: String?
    @Published var selectedObjectInfo: SelectedObjectInfo?
    @Published private(set) var cameraResetRequestID = 0
    @Published private(set) var asteroidField = AsteroidField(count: 0)
    let ephemerisPresets = EphemerisPresetCatalog.presets
    let cometField = CometVisualField()
    let minorBodyField = MinorBodyVisualField()

    var cameraLockDisplayName: String {
        cameraLockTargetName ?? "None"
    }

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
    private var currentEphemerisSnapshot: EphemerisSnapshot?
    private var ephemerisVisualStatesByName: [String: EphemerisBodyState] = [:]

    init() {
        reset()
    }

    deinit {
        simulationTask?.cancel()
        workerSyncTask?.cancel()
    }

    func reset() {
        stopForReset()
        asteroidField = AsteroidField(count: showAsteroidBelt ? defaultAsteroidVisualCount : 0)

        do {
            let snapshot = try EphemerisSnapshotStore.shared.loadSnapshot(presetID: selectedEphemerisPresetID)
            applyEphemerisSnapshot(snapshot, resetCamera: true)
        } catch {
            ephemerisLoadError = error.localizedDescription
            applyFallbackInitialBodies(resetCamera: true)
        }
    }

    func jumpToEphemerisPreset(_ preset: EphemerisDatePreset) {
        jumpToEphemerisPreset(id: preset.id)
    }

    func jumpToEphemerisPreset(id: String) {
        selectedEphemerisPresetID = id
        stopForReset()
        asteroidField = AsteroidField(count: showAsteroidBelt ? defaultAsteroidVisualCount : 0)

        do {
            let snapshot = try EphemerisSnapshotStore.shared.loadSnapshot(presetID: id)
            applyEphemerisSnapshot(snapshot, resetCamera: false)
        } catch {
            ephemerisLoadError = error.localizedDescription
        }
    }

    private func stopForReset() {
        simulationTask?.cancel()
        simulationTask = nil
        workerSyncTask?.cancel()
        isRunning = false
        currentTime = 0
        accumulatedTime = 0
        accumulatedSimulationDebt = 0
        lastFrameTime = nil
    }

    private func applyFallbackInitialBodies(resetCamera: Bool) {
        currentEphemerisSnapshot = nil
        ephemerisVisualStatesByName.removeAll()
        currentSimulationDate = EphemerisPresetCatalog.noonUTCDate(for: selectedEphemerisPresetID) ?? currentSimulationDate
        updateCurrentSimulationDateText()
        let newBodies = Self.makeInitialBodies()
        setBodies(newBodies, resetCamera: resetCamera)
    }

    private func applyEphemerisSnapshot(_ snapshot: EphemerisSnapshot, resetCamera: Bool) {
        let stateByName = Dictionary(snapshot.states.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var newBodies = Self.makeInitialBodies().map { body in
            if body.name == "Sun" {
                return replacingState(
                    of: body,
                    position: SIMD3<Double>(0, 0, 0),
                    velocity: SIMD3<Double>(0, 0, 0)
                )
            }

            guard let state = stateByName[body.name] else {
                return body
            }

            return replacingState(
                of: body,
                position: state.positionVector,
                velocity: state.velocityVector
            )
        }

        let bodyByName = Dictionary(newBodies.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for index in newBodies.indices {
            guard let parentName = newBodies[index].parentName,
                  let parent = bodyByName[parentName] else {
                continue
            }

            let relativePosition = newBodies[index].position - parent.position
            if simd_length_squared(relativePosition) > 0 {
                newBodies[index].orbitalPhase = atan2(relativePosition.y, relativePosition.x)
            }
        }

        for index in newBodies.indices {
            newBodies[index].cumulativePosition.removeAll(keepingCapacity: true)
            if newBodies[index].showsTrail {
                newBodies[index].cumulativePosition.append(newBodies[index].position)
            }
        }

        currentEphemerisSnapshot = snapshot
        ephemerisVisualStatesByName = stateByName
        selectedEphemerisPresetID = snapshot.presetID
        currentSimulationDate = DateFormatters.ephemerisTimestampUTC.date(from: snapshot.internalTimestampUTC)
            ?? EphemerisPresetCatalog.noonUTCDate(isoDate: snapshot.isoDate)
            ?? currentSimulationDate
        updateCurrentSimulationDateText()
        ephemerisLoadError = validationMessage(for: snapshot, stateByName: stateByName)

        print("Loaded ephemeris snapshot \(snapshot.presetID) with \(snapshot.states.count) states.")
        setBodies(newBodies, resetCamera: resetCamera)
    }

    private func replacingState(
        of body: CelestialBody,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>
    ) -> CelestialBody {
        CelestialBody(
            name: body.name,
            mass: body.mass,
            visualRadius: body.visualRadius,
            position: position,
            velocity: velocity,
            color: body.color,
            kind: body.kind,
            isStar: body.isStar,
            isMoon: body.isMoon,
            isAsteroid: body.isAsteroid,
            showsTrail: body.showsTrail,
            parentName: body.parentName,
            orbitalRadius: body.orbitalRadius,
            orbitalSpeed: body.orbitalSpeed,
            orbitalPeriodSeconds: body.orbitalPeriodSeconds,
            orbitalPhase: body.orbitalPhase
        )
    }

    private func setBodies(_ newBodies: [CelestialBody], resetCamera: Bool) {
        bodies = newBodies
        updateSelectedObjectInfo()
        validateCameraLockTarget()

        if resetCamera {
            cameraResetRequestID += 1
        }

        workerSyncTask = Task { [simulationWorker] in
            await simulationWorker.setBodies(newBodies)
        }
    }

    private func validationMessage(
        for snapshot: EphemerisSnapshot,
        stateByName: [String: EphemerisBodyState]
    ) -> String? {
        let physicsBodyNames = Self.makeInitialBodies().map(\.name)
        let missingPhysicsNames = physicsBodyNames.filter { $0 != "Sun" && stateByName[$0] == nil }
        if !missingPhysicsNames.isEmpty {
            print("Ephemeris snapshot \(snapshot.presetID) is missing non-Sun physics states: \(missingPhysicsNames.joined(separator: ", ")).")
        }

        let criticalNames = ["Sun", "Mercury", "Venus", "Earth", "Moon", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
        let missingCriticalNames = criticalNames.filter { $0 != "Sun" && stateByName[$0] == nil }

        guard !missingCriticalNames.isEmpty else {
            return nil
        }

        let message = "Ephemeris snapshot \(snapshot.presetID) is missing critical states: \(missingCriticalNames.joined(separator: ", "))."
        print(message)
        return message
    }

    private func updateCurrentSimulationDateText() {
        currentSimulationDateText = DateFormatters.simulationDateUTC.string(from: currentSimulationDate)
    }

    private func advanceSimulationClock(by seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        accumulatedTime += seconds
        currentTime = accumulatedTime
        currentSimulationDate = currentSimulationDate.addingTimeInterval(seconds)
        updateCurrentSimulationDateText()
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
                self.advanceSimulationClock(by: dt)
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

    var cameraLockTargets: [CameraLockTarget] {
        var targets: [CameraLockTarget] = []

        for body in bodies where shouldShowInCameraLockMenu(body) {
            targets.append(CameraLockTarget(id: body.name, name: body.name, kind: body.kind))
        }

        if showDwarfPlanets {
            targets.append(
                contentsOf: DwarfPlanetCatalog.recognizedDwarfPlanets.map {
                    CameraLockTarget(id: $0.name, name: $0.name, kind: .dwarfPlanet)
                }
            )
        }

        if showNotableAsteroids {
            targets.append(
                contentsOf: NotableAsteroidCatalog.notableAsteroids.map {
                    CameraLockTarget(id: $0.name, name: $0.name, kind: .asteroid)
                }
            )
        }

        if showComets {
            targets.append(
                contentsOf: CometCatalog.notableComets.map {
                    CameraLockTarget(id: $0.name, name: $0.name, kind: .comet)
                }
            )
        }

        if showAsteroidBelt {
            targets.append(CameraLockTarget(id: "Asteroid Belt", name: "Asteroid Belt", kind: .asteroidBelt))
        }

        var seen = Set<String>()
        let uniqueTargets = targets.filter { target in
            if seen.contains(target.id) {
                return false
            }

            seen.insert(target.id)
            return true
        }

        return uniqueTargets.sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }

            return $0.name < $1.name
        }
    }

    func isPlanetVisible(_ name: String) -> Bool {
        visiblePlanetNames.contains(name)
    }

    func setPlanetVisible(_ name: String, isVisible: Bool) {
        if isVisible {
            visiblePlanetNames.insert(name)
        } else {
            visiblePlanetNames.remove(name)
        }

        validateCameraLockTarget()
    }

    func lockCamera(to objectName: String?) {
        cameraLockTargetName = objectName
        validateCameraLockTarget()
    }

    func clearCameraLock() {
        cameraLockTargetName = nil
    }

    func validateCameraLockTarget() {
        guard let cameraLockTargetName else { return }

        if !cameraLockTargets.contains(where: { $0.id == cameraLockTargetName }) {
            clearCameraLock()
        }
    }

    func centerCameraOnObject(named name: String) {
        requestedCameraTargetName = name
    }

    func clearCameraTargetRequest() {
        requestedCameraTargetName = nil
    }

    func requestCameraPreset(_ preset: CameraPreset) {
        requestedCameraPreset = preset
    }

    func clearCameraPresetRequest() {
        requestedCameraPreset = nil
    }

    func selectObject(named name: String) {
        selectedObjectName = name
        updateSelectedObjectInfo()
    }

    func clearSelection() {
        selectedObjectName = nil
        selectedObjectInfo = nil
    }

    func cometVisualInstancesForRendering() -> [CometVisualInstance] {
        cometField.instances(at: currentTime).map { instance in
            guard let state = ephemerisState(named: instance.definition.name, aliases: [instance.definition.shortName]) else {
                return instance
            }

            let positionAU = ephemerisPositionAU(from: state, elapsedTime: currentTime)
            let distanceFromSun = max(simd_length(positionAU), 0.001)
            let sunDirection = simd_normalize(-positionAU)
            let activity = min(max((3.0 - distanceFromSun) / 3.0, 0.0), 1.0)
            var updatedInstance = instance
            updatedInstance.positionAU = positionAU
            updatedInstance.sunDirection = sunDirection
            updatedInstance.tailLengthAU = instance.definition.tailLengthAU * activity
            updatedInstance.comaRadiusAU = instance.definition.comaRadiusAU * (0.25 + 0.75 * activity)
            return updatedInstance
        }
    }

    func dwarfPlanetVisualInstancesForRendering() -> [MinorBodyVisualInstance] {
        minorBodyField.dwarfPlanetInstances(at: currentTime, excluding: ["Pluto"]).map(ephemerisAdjustedMinorBodyInstance)
    }

    func notableAsteroidVisualInstancesForRendering() -> [MinorBodyVisualInstance] {
        minorBodyField.notableAsteroidInstances(at: currentTime).map(ephemerisAdjustedMinorBodyInstance)
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

        if let minorBody = minorBodyField.definition(named: selectedObjectName) {
            selectedObjectInfo = makeSelectedInfo(for: minorBody, simulationTime: currentTime)
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
                        self.advanceSimulationClock(by: simulatedTimeAdvanced)
                        self.bodies = steppedBodies
                        self.updateSelectedObjectInfo()
                    } else {
                        await self.simulationWorker.advanceWithoutSnapshot(
                            substeps: substeps,
                            dt: physicsStepDt
                        )
                        guard !Task.isCancelled else { return }
                        self.advanceSimulationClock(by: simulatedTimeAdvanced)
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

    private func shouldShowInCameraLockMenu(_ body: CelestialBody) -> Bool {
        switch body.kind {
        case .star, .moon:
            if body.parentName == "Pluto" {
                return showDwarfPlanets
            }
            return true
        case .planet:
            return visiblePlanetNames.contains(body.name)
        case .dwarfPlanet:
            return showDwarfPlanets
        default:
            return false
        }
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
        let planetFacts = PlanetFactCatalog.byName[body.name]
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
            dateText: currentSimulationDateText,
            massKg: body.mass,
            radiusMeters: body.visualRadius,
            circumferenceMeters: circumference,
            distanceToSunMeters: body.isStar ? nil : distanceToSun,
            distanceToParentMeters: distanceToParent,
            orbitalPeriodSeconds: body.isStar ? nil : orbitalPeriod,
            axialTiltDegrees: planetFacts?.axialTiltDegrees,
            rotationPeriodHours: planetFacts?.rotationPeriodHours,
            lengthOfDayHours: planetFacts?.lengthOfDayHours,
            orbitalPeriodYears: planetFacts?.orbitalPeriodYears,
            rotationDirection: planetFacts?.rotationDirection,
            speedMetersPerSecond: speed,
            apsisPhase: apsisPhase(for: body, primary: parent ?? sun),
            notes: nil
        )
    }

    private func makeSelectedInfo(for comet: CometDefinition, simulationTime: Double) -> SelectedObjectInfo {
        let state = ephemerisState(named: comet.name, aliases: [comet.shortName])
        let positionAU = state.map { ephemerisPositionAU(from: $0, elapsedTime: simulationTime) }
            ?? KeplerOrbitSolver.positionAU(definition: comet, simulationTime: simulationTime)
        let futurePositionAU = state.map { ephemerisPositionAU(from: $0, elapsedTime: simulationTime + 3_600) }
            ?? KeplerOrbitSolver.positionAU(definition: comet, simulationTime: simulationTime + 3_600)
        let distanceToSun = Double(simd_length(positionAU)) * SolarSystemConstants.astronomicalUnit
        let futureDistanceToSun = Double(simd_length(futurePositionAU)) * SolarSystemConstants.astronomicalUnit
        let radius = Double(comet.nucleusRadiusAU) * SolarSystemConstants.astronomicalUnit
        let orbitalPeriod = SolarSystemConstants.yearsToSeconds(comet.periodYears)
        let speed = state.map { simd_length($0.velocityVector) }
            ?? cometSpeed(distanceMeters: distanceToSun, semiMajorAxisAU: comet.semiMajorAxisAU)
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
            dateText: currentSimulationDateText,
            massKg: nil,
            radiusMeters: radius,
            circumferenceMeters: 2 * Double.pi * radius,
            distanceToSunMeters: distanceToSun,
            distanceToParentMeters: nil,
            orbitalPeriodSeconds: orbitalPeriod,
            axialTiltDegrees: nil,
            rotationPeriodHours: nil,
            lengthOfDayHours: nil,
            orbitalPeriodYears: nil,
            rotationDirection: nil,
            speedMetersPerSecond: speed,
            apsisPhase: apsisPhase,
            notes: [comet.notes, "Analytic visual comet; not N-body simulated."].compactMap { $0 }.joined(separator: " ")
        )
    }

    private func makeSelectedInfo(for minorBody: MinorBodyDefinition, simulationTime: Double) -> SelectedObjectInfo {
        let state = ephemerisState(
            named: minorBody.name,
            aliases: minorBodySnapshotAliases(for: minorBody.name)
        )
        let positionAU = state.map { ephemerisPositionAU(from: $0, elapsedTime: simulationTime) }
            ?? KeplerOrbitSolver.positionAU(definition: minorBody, simulationTime: simulationTime)
        let futurePositionAU = state.map { ephemerisPositionAU(from: $0, elapsedTime: simulationTime + 3_600) }
            ?? KeplerOrbitSolver.positionAU(definition: minorBody, simulationTime: simulationTime + 3_600)
        let distanceToSun = Double(simd_length(positionAU)) * SolarSystemConstants.astronomicalUnit
        let futureDistanceToSun = Double(simd_length(futurePositionAU)) * SolarSystemConstants.astronomicalUnit
        let speed = state.map { simd_length($0.velocityVector) }
            ?? cometSpeed(distanceMeters: distanceToSun, semiMajorAxisAU: minorBody.semiMajorAxisAU)
        let apsisPhase: ApsisPhase

        if abs(futureDistanceToSun - distanceToSun) < 1_000 {
            apsisPhase = .unknown
        } else {
            apsisPhase = futureDistanceToSun > distanceToSun ? .movingTowardAphelion : .movingTowardPerihelion
        }

        return SelectedObjectInfo(
            id: minorBody.id,
            name: minorBody.name,
            kind: minorBody.kind,
            parentName: "Sun",
            dateText: currentSimulationDateText,
            massKg: minorBody.massKg,
            radiusMeters: minorBody.meanRadiusMeters,
            circumferenceMeters: minorBody.circumferenceMeters,
            distanceToSunMeters: distanceToSun,
            distanceToParentMeters: nil,
            orbitalPeriodSeconds: minorBody.orbitalPeriodSeconds,
            axialTiltDegrees: nil,
            rotationPeriodHours: nil,
            lengthOfDayHours: nil,
            orbitalPeriodYears: nil,
            rotationDirection: nil,
            speedMetersPerSecond: speed,
            apsisPhase: apsisPhase,
            notes: [minorBody.notes, "Analytic visual object; not N-body simulated."].compactMap { $0 }.joined(separator: " ")
        )
    }

    private func makeAsteroidBeltInfo() -> SelectedObjectInfo {
        SelectedObjectInfo(
            id: asteroidBeltSelectionID,
            name: "Asteroid Belt",
            kind: .asteroidBelt,
            parentName: "Sun",
            dateText: currentSimulationDateText,
            massKg: nil,
            radiusMeters: nil,
            circumferenceMeters: nil,
            distanceToSunMeters: 2.7 * SolarSystemConstants.astronomicalUnit,
            distanceToParentMeters: nil,
            orbitalPeriodSeconds: nil,
            axialTiltDegrees: nil,
            rotationPeriodHours: nil,
            lengthOfDayHours: nil,
            orbitalPeriodYears: nil,
            rotationDirection: nil,
            speedMetersPerSecond: nil,
            apsisPhase: .notApplicable,
            notes: "Aesthetic asteroid field; not N-body simulated. Individual asteroids use analytic visual orbits."
        )
    }

    private func ephemerisAdjustedMinorBodyInstance(_ instance: MinorBodyVisualInstance) -> MinorBodyVisualInstance {
        guard let state = ephemerisState(
            named: instance.definition.name,
            aliases: minorBodySnapshotAliases(for: instance.definition.name)
        ) else {
            return instance
        }

        return MinorBodyVisualInstance(
            definition: instance.definition,
            positionAU: ephemerisPositionAU(from: state, elapsedTime: currentTime),
            renderRadiusAU: instance.renderRadiusAU,
            color: instance.color,
            meshVariant: instance.meshVariant
        )
    }

    private func ephemerisState(named name: String, aliases: [String] = []) -> EphemerisBodyState? {
        if let state = ephemerisVisualStatesByName[name] {
            return state
        }

        for alias in aliases {
            if let state = ephemerisVisualStatesByName[alias] {
                return state
            }
        }

        return nil
    }

    private func ephemerisPositionAU(from state: EphemerisBodyState, elapsedTime: Double) -> SIMD3<Float> {
        let position = state.positionVector + state.velocityVector * elapsedTime
        let au = SolarSystemConstants.astronomicalUnit
        return SIMD3<Float>(
            Float(position.x / au),
            Float(position.y / au),
            Float(position.z / au)
        )
    }

    private func distanceMeters(from state: EphemerisBodyState, elapsedTime: Double) -> Double {
        simd_length(state.positionVector + state.velocityVector * elapsedTime)
    }

    private func minorBodySnapshotAliases(for name: String) -> [String] {
        switch name {
        case "4 Vesta":
            return ["Vesta"]
        case "2 Pallas":
            return ["Pallas"]
        case "10 Hygiea":
            return ["Hygiea"]
        default:
            return []
        }
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
            color: SIMD4<Float>,
            kind: CelestialObjectKind = .planet,
            showsTrail: Bool = true,
            orbitalPeriodSeconds: Double? = nil
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
                    kind: kind,
                    showsTrail: showsTrail,
                    orbitalPeriodSeconds: orbitalPeriodSeconds ?? SolarSystemConstants.siderealOrbitalPeriodSeconds(forPlanetNamed: name)
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
        let pluto = addPlanet(
            name: "Pluto",
            mass: 1.303e22,
            radius: 1_188_300,
            orbitalRadiusAU: 39.482,
            orbitalSpeed: 4_740,
            color: SIMD4<Float>(0.70, 0.58, 0.45, 1),
            kind: .dwarfPlanet,
            orbitalPeriodSeconds: SolarSystemConstants.yearsToSeconds(247.94)
        )

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
        addMoon(&result, name: "Hyperion", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 5.62e18, radius: 135_000, distanceFromParent: 1_481_100_000, orbitalSpeed: 5_070, color: SIMD4<Float>(0.55, 0.50, 0.43, 1))
        addMoon(&result, name: "Iapetus", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.8056e21, radius: 734_500, distanceFromParent: 3_560_820_000, orbitalSpeed: 3_260, color: SIMD4<Float>(0.60, 0.56, 0.50, 1))
        addMoon(&result, name: "Phoebe", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 8.292e18, radius: 106_500, distanceFromParent: 12_952_000_000, orbitalSpeed: 1_710, color: SIMD4<Float>(0.30, 0.28, 0.26, 1))
        addMoon(&result, name: "Janus", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 1.897e18, radius: 89_500, distanceFromParent: 151_500_000, orbitalSpeed: 15_900, color: SIMD4<Float>(0.62, 0.59, 0.54, 1))
        addMoon(&result, name: "Epimetheus", parentName: "Saturn", parentPosition: saturn.position, parentVelocity: saturn.velocity, mass: 5.266e17, radius: 58_100, distanceFromParent: 151_400_000, orbitalSpeed: 15_900, color: SIMD4<Float>(0.60, 0.58, 0.53, 1))

        addMoon(&result, name: "Miranda", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 6.59e19, radius: 235_800, distanceFromParent: 129_390_000, orbitalSpeed: 6_680, color: SIMD4<Float>(0.62, 0.65, 0.62, 1))
        addMoon(&result, name: "Ariel", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 1.353e21, radius: 578_900, distanceFromParent: 191_020_000, orbitalSpeed: 5_510, color: SIMD4<Float>(0.68, 0.70, 0.68, 1))
        addMoon(&result, name: "Umbriel", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 1.172e21, radius: 584_700, distanceFromParent: 266_300_000, orbitalSpeed: 4_670, color: SIMD4<Float>(0.45, 0.46, 0.45, 1))
        addMoon(&result, name: "Titania", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 3.527e21, radius: 788_900, distanceFromParent: 435_910_000, orbitalSpeed: 3_640, color: SIMD4<Float>(0.64, 0.66, 0.62, 1))
        addMoon(&result, name: "Oberon", parentName: "Uranus", parentPosition: uranus.position, parentVelocity: uranus.velocity, mass: 3.014e21, radius: 761_400, distanceFromParent: 583_520_000, orbitalSpeed: 3_150, color: SIMD4<Float>(0.55, 0.54, 0.50, 1))

        addMoon(&result, name: "Naiad", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 1.9e17, radius: 33_000, distanceFromParent: 48_227_000, orbitalSpeed: 13_100, color: SIMD4<Float>(0.34, 0.34, 0.33, 1))
        addMoon(&result, name: "Thalassa", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 3.5e17, radius: 41_000, distanceFromParent: 50_074_000, orbitalSpeed: 12_840, color: SIMD4<Float>(0.34, 0.34, 0.33, 1))
        addMoon(&result, name: "Despina", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 2.1e18, radius: 75_000, distanceFromParent: 52_526_000, orbitalSpeed: 12_530, color: SIMD4<Float>(0.35, 0.35, 0.34, 1))
        addMoon(&result, name: "Galatea", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 2.12e18, radius: 88_000, distanceFromParent: 61_953_000, orbitalSpeed: 11_480, color: SIMD4<Float>(0.36, 0.36, 0.35, 1))
        addMoon(&result, name: "Larissa", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 4.2e18, radius: 97_000, distanceFromParent: 73_548_000, orbitalSpeed: 10_180, color: SIMD4<Float>(0.38, 0.38, 0.36, 1))
        addMoon(&result, name: "Proteus", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 4.4e19, radius: 210_000, distanceFromParent: 117_647_000, orbitalSpeed: 7_630, color: SIMD4<Float>(0.42, 0.42, 0.40, 1))
        addMoon(&result, name: "Triton", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 2.14e22, radius: 1_353_400, distanceFromParent: 354_759_000, orbitalSpeed: 4_390, color: SIMD4<Float>(0.72, 0.70, 0.66, 1))
        addMoon(&result, name: "Nereid", parentName: "Neptune", parentPosition: neptune.position, parentVelocity: neptune.velocity, mass: 3.1e19, radius: 170_000, distanceFromParent: 5_513_400_000, orbitalSpeed: 950, color: SIMD4<Float>(0.50, 0.50, 0.48, 1))

        addMoon(&result, name: "Charon", parentName: "Pluto", parentPosition: pluto.position, parentVelocity: pluto.velocity, mass: 1.586e21, radius: 606_000, distanceFromParent: 19_596_000, orbitalSpeed: 210, color: SIMD4<Float>(0.55, 0.52, 0.50, 1))
        addMoon(&result, name: "Styx", parentName: "Pluto", parentPosition: pluto.position, parentVelocity: pluto.velocity, mass: 7.5e15, radius: 8_000, distanceFromParent: 42_700_000, orbitalSpeed: 150, color: SIMD4<Float>(0.48, 0.48, 0.46, 1))
        addMoon(&result, name: "Nix", parentName: "Pluto", parentPosition: pluto.position, parentVelocity: pluto.velocity, mass: 4.5e16, radius: 20_000, distanceFromParent: 48_700_000, orbitalSpeed: 140, color: SIMD4<Float>(0.50, 0.50, 0.48, 1))
        addMoon(&result, name: "Kerberos", parentName: "Pluto", parentPosition: pluto.position, parentVelocity: pluto.velocity, mass: 1.65e16, radius: 12_000, distanceFromParent: 57_800_000, orbitalSpeed: 130, color: SIMD4<Float>(0.48, 0.48, 0.46, 1))
        addMoon(&result, name: "Hydra", parentName: "Pluto", parentPosition: pluto.position, parentVelocity: pluto.velocity, mass: 4.8e16, radius: 25_000, distanceFromParent: 64_700_000, orbitalSpeed: 120, color: SIMD4<Float>(0.52, 0.52, 0.50, 1))

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

import Foundation

nonisolated enum CelestialObjectKind: String, Codable, Hashable, Sendable {
    case star = "Star"
    case planet = "Planet"
    case moon = "Moon"
    case comet = "Comet"
    case asteroid = "Asteroid"
    case asteroidBelt = "Asteroid Belt"
    case dwarfPlanet = "Dwarf Planet"
    case unknown = "Unknown"
}

nonisolated enum ApsisPhase: String, Sendable {
    case movingTowardPerihelion = "Moving toward perihelion"
    case movingTowardAphelion = "Moving toward aphelion"
    case movingTowardPerigee = "Moving toward perigee"
    case movingTowardApogee = "Moving toward apogee"
    case movingTowardPeriapsis = "Moving toward periapsis"
    case movingTowardApoapsis = "Moving toward apoapsis"
    case nearPeriapsis = "Near periapsis"
    case nearApoapsis = "Near apoapsis"
    case notApplicable = "Not applicable"
    case unknown = "Unknown"
}

nonisolated struct SelectedObjectInfo: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let kind: CelestialObjectKind
    let parentName: String?
    let dateText: String?
    let massKg: Double?
    let radiusMeters: Double?
    let circumferenceMeters: Double?
    let distanceToSunMeters: Double?
    let distanceToParentMeters: Double?
    let orbitalPeriodSeconds: Double?
    let axialTiltDegrees: Double?
    let rotationPeriodHours: Double?
    let lengthOfDayHours: Double?
    let orbitalPeriodYears: Double?
    let rotationDirection: String?
    let speedMetersPerSecond: Double?
    let apsisPhase: ApsisPhase
    let notes: String?
}

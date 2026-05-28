import Foundation
import simd

nonisolated struct MinorBodyDefinition: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let kind: CelestialObjectKind
    let massKg: Double?
    let meanRadiusMeters: Double?
    let orbitalPeriodYears: Double
    let semiMajorAxisAU: Double
    let eccentricity: Double
    let inclinationDegrees: Double
    let longitudeOfAscendingNodeDegrees: Double
    let argumentOfPerihelionDegrees: Double
    let phaseOffsetRadians: Double
    let color: SIMD4<Float>
    let renderRadiusAU: Float
    let notes: String?

    var orbitalPeriodSeconds: Double {
        SolarSystemConstants.yearsToSeconds(orbitalPeriodYears)
    }

    var circumferenceMeters: Double? {
        guard let meanRadiusMeters else { return nil }
        return 2.0 * Double.pi * meanRadiusMeters
    }
}

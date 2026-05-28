import Foundation
import simd

nonisolated struct CometDefinition: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let shortName: String
    let periodYears: Double
    let perihelionAU: Double
    let eccentricity: Double
    let inclinationDegrees: Double
    let longitudeOfAscendingNodeDegrees: Double
    let argumentOfPerihelionDegrees: Double
    let phaseOffsetRadians: Double
    let nucleusRadiusAU: Float
    let comaRadiusAU: Float
    let tailLengthAU: Float
    let color: SIMD4<Float>
    let notes: String?

    init(
        name: String,
        shortName: String,
        periodYears: Double,
        perihelionAU: Double,
        eccentricity: Double,
        inclinationDegrees: Double,
        longitudeOfAscendingNodeDegrees: Double,
        argumentOfPerihelionDegrees: Double,
        phaseOffsetRadians: Double,
        nucleusRadiusAU: Float,
        comaRadiusAU: Float,
        tailLengthAU: Float,
        color: SIMD4<Float>,
        notes: String? = nil
    ) {
        self.name = name
        self.shortName = shortName
        self.periodYears = periodYears
        self.perihelionAU = perihelionAU
        self.eccentricity = eccentricity
        self.inclinationDegrees = inclinationDegrees
        self.longitudeOfAscendingNodeDegrees = longitudeOfAscendingNodeDegrees
        self.argumentOfPerihelionDegrees = argumentOfPerihelionDegrees
        self.phaseOffsetRadians = phaseOffsetRadians
        self.nucleusRadiusAU = nucleusRadiusAU
        self.comaRadiusAU = comaRadiusAU
        self.tailLengthAU = tailLengthAU
        self.color = color
        self.notes = notes
    }

    var semiMajorAxisAU: Double {
        perihelionAU / max(1.0 - eccentricity, 0.000001)
    }

    var meanMotionRadiansPerSecond: Double {
        2.0 * Double.pi / SolarSystemConstants.yearsToSeconds(periodYears)
    }
}

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

    var semiMajorAxisAU: Double {
        perihelionAU / max(1.0 - eccentricity, 0.000001)
    }

    var meanMotionRadiansPerSecond: Double {
        2.0 * Double.pi / SolarSystemConstants.yearsToSeconds(periodYears)
    }
}

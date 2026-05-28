import Foundation
import simd

nonisolated enum KeplerOrbitSolver {
    static func positionAU(definition: CometDefinition, simulationTime: Double) -> SIMD3<Float> {
        let meanAnomaly = definition.meanMotionRadiansPerSecond * simulationTime + definition.phaseOffsetRadians
        return positionAU(definition: definition, meanAnomaly: meanAnomaly)
    }

    static func positionAU(definition: CometDefinition, meanAnomaly: Double) -> SIMD3<Float> {
        positionAU(
            semiMajorAxisAU: definition.semiMajorAxisAU,
            eccentricity: definition.eccentricity,
            inclinationDegrees: definition.inclinationDegrees,
            longitudeOfAscendingNodeDegrees: definition.longitudeOfAscendingNodeDegrees,
            argumentOfPerihelionDegrees: definition.argumentOfPerihelionDegrees,
            meanAnomaly: meanAnomaly
        )
    }

    static func positionAU(definition: MinorBodyDefinition, simulationTime: Double) -> SIMD3<Float> {
        let meanMotion = 2.0 * Double.pi / definition.orbitalPeriodSeconds
        let meanAnomaly = meanMotion * simulationTime + definition.phaseOffsetRadians
        return positionAU(definition: definition, meanAnomaly: meanAnomaly)
    }

    static func positionAU(definition: MinorBodyDefinition, meanAnomaly: Double) -> SIMD3<Float> {
        positionAU(
            semiMajorAxisAU: definition.semiMajorAxisAU,
            eccentricity: definition.eccentricity,
            inclinationDegrees: definition.inclinationDegrees,
            longitudeOfAscendingNodeDegrees: definition.longitudeOfAscendingNodeDegrees,
            argumentOfPerihelionDegrees: definition.argumentOfPerihelionDegrees,
            meanAnomaly: meanAnomaly
        )
    }

    private static func positionAU(
        semiMajorAxisAU: Double,
        eccentricity: Double,
        inclinationDegrees: Double,
        longitudeOfAscendingNodeDegrees: Double,
        argumentOfPerihelionDegrees: Double,
        meanAnomaly: Double
    ) -> SIMD3<Float> {
        let eccentricity = min(max(eccentricity, 0), 0.999999)
        let normalizedMeanAnomaly = normalizeAngle(meanAnomaly)
        let eccentricAnomaly = solveEccentricAnomaly(meanAnomaly: normalizedMeanAnomaly, eccentricity: eccentricity)
        let halfE = eccentricAnomaly * 0.5
        let trueAnomaly = 2 * atan2(
            sqrt(1 + eccentricity) * sin(halfE),
            sqrt(max(1 - eccentricity, 0.000001)) * cos(halfE)
        )
        let radius = semiMajorAxisAU * (1 - eccentricity * cos(eccentricAnomaly))

        return rotateOrbitalPlanePosition(
            radius: radius,
            trueAnomaly: trueAnomaly,
            inclinationDegrees: inclinationDegrees,
            longitudeOfAscendingNodeDegrees: longitudeOfAscendingNodeDegrees,
            argumentOfPerihelionDegrees: argumentOfPerihelionDegrees
        )
    }

    private static func solveEccentricAnomaly(meanAnomaly: Double, eccentricity: Double) -> Double {
        var eccentricAnomaly = eccentricity < 0.8 ? meanAnomaly : Double.pi

        for _ in 0..<12 {
            let f = eccentricAnomaly - eccentricity * sin(eccentricAnomaly) - meanAnomaly
            let derivative = max(1 - eccentricity * cos(eccentricAnomaly), 0.000001)
            let delta = f / derivative
            eccentricAnomaly -= delta

            if abs(delta) < 1.0e-10 {
                break
            }
        }

        return eccentricAnomaly
    }

    private static func rotateOrbitalPlanePosition(
        radius: Double,
        trueAnomaly: Double,
        inclinationDegrees: Double,
        longitudeOfAscendingNodeDegrees: Double,
        argumentOfPerihelionDegrees: Double
    ) -> SIMD3<Float> {
        let inclination = degreesToRadians(inclinationDegrees)
        let longitudeOfAscendingNode = degreesToRadians(longitudeOfAscendingNodeDegrees)
        let argumentOfPerihelion = degreesToRadians(argumentOfPerihelionDegrees)
        let argumentPlusTrueAnomaly = argumentOfPerihelion + trueAnomaly

        let cosOmega = cos(longitudeOfAscendingNode)
        let sinOmega = sin(longitudeOfAscendingNode)
        let cosInclination = cos(inclination)
        let sinInclination = sin(inclination)
        let cosArgument = cos(argumentPlusTrueAnomaly)
        let sinArgument = sin(argumentPlusTrueAnomaly)

        let x = radius * (cosOmega * cosArgument - sinOmega * sinArgument * cosInclination)
        let y = radius * (sinOmega * cosArgument + cosOmega * sinArgument * cosInclination)
        let z = radius * (sinArgument * sinInclination)

        return SIMD3<Float>(Float(x), Float(y), Float(z))
    }

    private static func normalizeAngle(_ angle: Double) -> Double {
        let period = Double.pi * 2
        var result = angle.truncatingRemainder(dividingBy: period)

        if result < 0 {
            result += period
        }

        return result
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * Double.pi / 180
    }
}

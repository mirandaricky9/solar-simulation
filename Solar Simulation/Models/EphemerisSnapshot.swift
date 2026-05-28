import Foundation
import simd

struct EphemerisSnapshot: Codable, Sendable {
    let presetID: String
    let isoDate: String
    let internalTimestampUTC: String
    let source: String
    let center: String
    let units: String
    let states: [EphemerisBodyState]
}

struct EphemerisBodyState: Codable, Sendable {
    let name: String
    let horizonsCommand: String
    let kind: String
    let parentName: String?
    let positionMeters: [Double]
    let velocityMetersPerSecond: [Double]
}

extension EphemerisBodyState {
    var positionVector: SIMD3<Double> {
        guard positionMeters.count >= 3 else { return SIMD3<Double>(0, 0, 0) }
        return SIMD3<Double>(positionMeters[0], positionMeters[1], positionMeters[2])
    }

    var velocityVector: SIMD3<Double> {
        guard velocityMetersPerSecond.count >= 3 else { return SIMD3<Double>(0, 0, 0) }
        return SIMD3<Double>(
            velocityMetersPerSecond[0],
            velocityMetersPerSecond[1],
            velocityMetersPerSecond[2]
        )
    }
}

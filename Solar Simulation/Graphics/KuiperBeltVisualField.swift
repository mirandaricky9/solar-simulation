import Foundation
import simd

struct KuiperBeltVisualInstance {
    var orbitRadiusAU: Float
    var initialAngle: Float
    var angularSpeed: Float
    var eccentricity: Float
    var inclination: Float
    var verticalOffsetAU: Float
    var sizeAU: Float
    var color: SIMD4<Float>
    var meshVariant: Int
}

final class KuiperBeltVisualField {
    private(set) var objects: [KuiperBeltVisualInstance] = []

    private let meshVariantCount: Int

    init(count: Int, meshVariantCount: Int = 12) {
        self.meshVariantCount = max(meshVariantCount, 1)
        generate(count: count)
    }

    func generate(count: Int) {
        var generator = KuiperSeededGenerator(seed: 0x4B55_1CE0_7A11_2026)
        let count = max(count, 0)
        let baseAngularSpeed = Float.pi * 2 / Float(SolarSystemConstants.secondsPerJulianYear)
        let minSize = log(Float(0.001))
        let maxSize = log(Float(0.006))

        objects.removeAll(keepingCapacity: true)
        objects.reserveCapacity(count)

        for index in 0..<count {
            let clustered = (generator.nextFloat() + generator.nextFloat() + generator.nextFloat()) / 3
            let orbitRadiusAU = 30 + clustered * 25
            let eccentricity = generator.nextFloat(in: 0...0.12)
            let inclination = generator.nextFloat(in: (-15 * Float.pi / 180)...(15 * Float.pi / 180))
            let sizeAU = exp(generator.nextFloat(in: minSize...maxSize))
            let ice = generator.nextFloat(in: 0.62...0.92)
            let color = SIMD4<Float>(ice * 0.78, ice * 0.88, min(ice * 1.08, 1), 0.82)

            objects.append(
                KuiperBeltVisualInstance(
                    orbitRadiusAU: orbitRadiusAU,
                    initialAngle: generator.nextFloat(in: 0...(Float.pi * 2)),
                    angularSpeed: sqrt(1 / pow(orbitRadiusAU, 3)) * baseAngularSpeed,
                    eccentricity: eccentricity,
                    inclination: inclination,
                    verticalOffsetAU: generator.nextFloat(in: -3.5...3.5),
                    sizeAU: sizeAU,
                    color: color,
                    meshVariant: index % meshVariantCount
                )
            )
        }
    }
}

private struct KuiperSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextFloat() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let value = UInt32(truncatingIfNeeded: state >> 32)
        return Float(value) / Float(UInt32.max)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + nextFloat() * (range.upperBound - range.lowerBound)
    }
}

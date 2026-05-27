import Foundation
import simd

struct AsteroidVisualInstance {
    var orbitRadiusAU: Float
    var initialAngle: Float
    var angularSpeed: Float
    var eccentricity: Float
    var inclination: Float
    var verticalOffsetAU: Float
    var sizeAU: Float
    var color: SIMD4<Float>
    var rotationAxis: SIMD3<Float>
    var rotationSpeed: Float
    var initialRotation: Float
    var meshVariant: Int
}

final class AsteroidField {
    private(set) var asteroids: [AsteroidVisualInstance] = []

    private let meshVariantCount: Int

    init(count: Int, meshVariantCount: Int = 12) {
        self.meshVariantCount = max(meshVariantCount, 1)
        generate(count: count)
    }

    func generate(count: Int) {
        var generator = SeededGenerator(seed: 0x6A09_E667_F3BC_C909)
        let count = max(count, 0)
        let baseAngularSpeed = Float.pi * 2 / Float(SolarSystemConstants.secondsPerJulianYear)
        let minSize = log(Float(0.0008))
        let maxSize = log(Float(0.006))

        asteroids.removeAll(keepingCapacity: true)
        asteroids.reserveCapacity(count)

        for index in 0..<count {
            let clustered = (generator.nextFloat() + generator.nextFloat() + generator.nextFloat()) / 3
            let orbitRadiusAU = 2.1 + clustered * 1.3
            let eccentricity = generator.nextFloat(in: 0...0.18)
            let inclination = generator.nextFloat(in: (-8 * Float.pi / 180)...(8 * Float.pi / 180))
            let sizeAU = exp(generator.nextFloat(in: minSize...maxSize))
            let brownShift = generator.nextFloat(in: -0.06...0.08)
            let gray = generator.nextFloat(in: 0.28...0.52)
            let color = SIMD4<Float>(
                gray + brownShift,
                gray * generator.nextFloat(in: 0.86...1.04),
                gray * generator.nextFloat(in: 0.72...0.94),
                1
            )
            let axis = simd_normalize(
                SIMD3<Float>(
                    generator.nextFloat(in: -1...1),
                    generator.nextFloat(in: -1...1),
                    generator.nextFloat(in: -1...1)
                )
            )

            asteroids.append(
                AsteroidVisualInstance(
                    orbitRadiusAU: orbitRadiusAU,
                    initialAngle: generator.nextFloat(in: 0...(Float.pi * 2)),
                    angularSpeed: sqrt(1 / pow(orbitRadiusAU, 3)) * baseAngularSpeed,
                    eccentricity: eccentricity,
                    inclination: inclination,
                    verticalOffsetAU: generator.nextFloat(in: -0.05...0.05),
                    sizeAU: sizeAU,
                    color: color,
                    rotationAxis: axis,
                    rotationSpeed: generator.nextFloat(in: -0.8...0.8),
                    initialRotation: generator.nextFloat(in: 0...(Float.pi * 2)),
                    meshVariant: index % meshVariantCount
                )
            )
        }
    }
}

private struct SeededGenerator {
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

import Foundation
import simd

struct OortCloudVisualInstance {
    var positionAU: SIMD3<Float>
    var sizeAU: Float
    var color: SIMD4<Float>
    var meshVariant: Int
}

final class OortCloudVisualField {
    private(set) var objects: [OortCloudVisualInstance] = []

    private let meshVariantCount: Int

    init(count: Int, meshVariantCount: Int = 12) {
        self.meshVariantCount = max(meshVariantCount, 1)
        generate(count: count)
    }

    func generate(count: Int) {
        var generator = OortSeededGenerator(seed: 0x0070_0C10_0D00_2026)
        let count = max(count, 0)
        let minRadius = log(Float(5_000))
        let maxRadius = log(Float(100_000))

        objects.removeAll(keepingCapacity: true)
        objects.reserveCapacity(count)

        for index in 0..<count {
            let radius = exp(generator.nextFloat(in: minRadius...maxRadius))
            let z = generator.nextFloat(in: -1...1)
            let theta = generator.nextFloat(in: 0...(Float.pi * 2))
            let radial = sqrt(max(0, 1 - z * z))
            let direction = SIMD3<Float>(radial * cos(theta), radial * sin(theta), z)
            let tint = generator.nextFloat(in: 0.66...0.96)

            objects.append(
                OortCloudVisualInstance(
                    positionAU: direction * radius,
                    sizeAU: generator.nextFloat(in: 0.003...0.012),
                    color: SIMD4<Float>(tint * 0.72, tint * 0.84, min(tint * 1.08, 1), 0.22),
                    meshVariant: index % meshVariantCount
                )
            )
        }
    }
}

private struct OortSeededGenerator {
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

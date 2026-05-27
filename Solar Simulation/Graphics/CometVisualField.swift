import Foundation
import simd

nonisolated struct CometVisualInstance {
    let definition: CometDefinition
    var positionAU: SIMD3<Float>
    var sunDirection: SIMD3<Float>
    var tailLengthAU: Float
    var comaRadiusAU: Float
    var nucleusRadiusAU: Float
    var color: SIMD4<Float>
}

nonisolated final class CometVisualField {
    var definitions: [CometDefinition] = CometCatalog.notableComets

    func instances(at simulationTime: Double) -> [CometVisualInstance] {
        definitions.map { definition in
            let position = KeplerOrbitSolver.positionAU(
                definition: definition,
                simulationTime: simulationTime
            )
            let distanceFromSun = max(simd_length(position), 0.001)
            let sunDirection = simd_normalize(-position)
            let activity = min(max((3.0 - distanceFromSun) / 3.0, 0.0), 1.0)

            return CometVisualInstance(
                definition: definition,
                positionAU: position,
                sunDirection: sunDirection,
                tailLengthAU: definition.tailLengthAU * activity,
                comaRadiusAU: definition.comaRadiusAU * (0.25 + 0.75 * activity),
                nucleusRadiusAU: definition.nucleusRadiusAU,
                color: definition.color
            )
        }
    }
}

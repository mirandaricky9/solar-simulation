import Foundation
import simd

nonisolated struct MinorBodyVisualInstance {
    let definition: MinorBodyDefinition
    let positionAU: SIMD3<Float>
    let renderRadiusAU: Float
    let color: SIMD4<Float>
    let meshVariant: Int
}

nonisolated final class MinorBodyVisualField {
    let dwarfPlanets = DwarfPlanetCatalog.recognizedDwarfPlanets
    let notableAsteroids = NotableAsteroidCatalog.notableAsteroids

    var allDefinitions: [MinorBodyDefinition] {
        dwarfPlanets + notableAsteroids
    }

    func dwarfPlanetInstances(at simulationTime: Double, excluding excludedNames: Set<String> = []) -> [MinorBodyVisualInstance] {
        instances(from: dwarfPlanets.filter { !excludedNames.contains($0.name) }, at: simulationTime)
    }

    func notableAsteroidInstances(at simulationTime: Double) -> [MinorBodyVisualInstance] {
        instances(from: notableAsteroids, at: simulationTime)
    }

    func definition(named name: String) -> MinorBodyDefinition? {
        allDefinitions.first { $0.name == name }
    }

    private func instances(from definitions: [MinorBodyDefinition], at simulationTime: Double) -> [MinorBodyVisualInstance] {
        definitions.enumerated().map { index, definition in
            MinorBodyVisualInstance(
                definition: definition,
                positionAU: KeplerOrbitSolver.positionAU(definition: definition, simulationTime: simulationTime),
                renderRadiusAU: definition.renderRadiusAU,
                color: definition.color,
                meshVariant: deterministicVariant(name: definition.name, index: index)
            )
        }
    }

    private func deterministicVariant(name: String, index: Int) -> Int {
        let scalarSum = name.unicodeScalars.reduce(index) { $0 + Int($1.value) }
        return abs(scalarSum * 31 + 7) % 12
    }
}

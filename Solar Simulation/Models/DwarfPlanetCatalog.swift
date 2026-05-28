import Foundation
import simd

nonisolated enum DwarfPlanetCatalog {
    // IAU currently recognizes five dwarf planets: Ceres, Pluto, Haumea, Makemake, and Eris.
    static let recognizedDwarfPlanets: [MinorBodyDefinition] = [
        MinorBodyDefinition(
            name: "Ceres",
            kind: .dwarfPlanet,
            massKg: 9.3835e20,
            meanRadiusMeters: 469_700,
            orbitalPeriodYears: 4.60,
            semiMajorAxisAU: 2.767,
            eccentricity: 0.079,
            inclinationDegrees: 10.6,
            longitudeOfAscendingNodeDegrees: 80.3,
            argumentOfPerihelionDegrees: 73.6,
            phaseOffsetRadians: 0.62,
            color: SIMD4<Float>(0.55, 0.52, 0.48, 1),
            renderRadiusAU: 0.010,
            notes: "IAU-recognized dwarf planet in the asteroid belt."
        ),
        MinorBodyDefinition(
            name: "Pluto",
            kind: .dwarfPlanet,
            massKg: 1.303e22,
            meanRadiusMeters: 1_188_300,
            orbitalPeriodYears: 247.94,
            semiMajorAxisAU: 39.482,
            eccentricity: 0.249,
            inclinationDegrees: 17.16,
            longitudeOfAscendingNodeDegrees: 110.3,
            argumentOfPerihelionDegrees: 113.8,
            phaseOffsetRadians: 2.45,
            color: SIMD4<Float>(0.70, 0.58, 0.45, 1),
            renderRadiusAU: 0.014,
            notes: "IAU-recognized dwarf planet in the Kuiper Belt."
        ),
        MinorBodyDefinition(
            name: "Haumea",
            kind: .dwarfPlanet,
            massKg: 4.006e21,
            meanRadiusMeters: 780_000,
            orbitalPeriodYears: 284.12,
            semiMajorAxisAU: 43.218,
            eccentricity: 0.195,
            inclinationDegrees: 28.2,
            longitudeOfAscendingNodeDegrees: 121.9,
            argumentOfPerihelionDegrees: 240.0,
            phaseOffsetRadians: 4.18,
            color: SIMD4<Float>(0.78, 0.78, 0.74, 1),
            renderRadiusAU: 0.012,
            notes: "IAU-recognized elongated dwarf planet in the Kuiper Belt."
        ),
        MinorBodyDefinition(
            name: "Makemake",
            kind: .dwarfPlanet,
            massKg: nil,
            meanRadiusMeters: 715_000,
            orbitalPeriodYears: 305.34,
            semiMajorAxisAU: 45.79,
            eccentricity: 0.161,
            inclinationDegrees: 29.0,
            longitudeOfAscendingNodeDegrees: 79.6,
            argumentOfPerihelionDegrees: 296.0,
            phaseOffsetRadians: 5.37,
            color: SIMD4<Float>(0.80, 0.70, 0.62, 1),
            renderRadiusAU: 0.012,
            notes: "IAU-recognized dwarf planet in the Kuiper Belt."
        ),
        MinorBodyDefinition(
            name: "Eris",
            kind: .dwarfPlanet,
            massKg: 1.6466e22,
            meanRadiusMeters: 1_163_000,
            orbitalPeriodYears: 559.0,
            semiMajorAxisAU: 67.78,
            eccentricity: 0.44,
            inclinationDegrees: 44.0,
            longitudeOfAscendingNodeDegrees: 35.9,
            argumentOfPerihelionDegrees: 151.6,
            phaseOffsetRadians: 3.04,
            color: SIMD4<Float>(0.82, 0.84, 0.86, 1),
            renderRadiusAU: 0.014,
            notes: "IAU-recognized scattered-disc dwarf planet."
        )
    ]
}

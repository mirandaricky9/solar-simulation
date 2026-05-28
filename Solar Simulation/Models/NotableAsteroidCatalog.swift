import Foundation
import simd

nonisolated enum NotableAsteroidCatalog {
    static let notableAsteroids: [MinorBodyDefinition] = [
        asteroid(
            name: "4 Vesta",
            massKg: 2.59076e20,
            meanRadiusMeters: 262_700,
            orbitalPeriodYears: 3.63,
            semiMajorAxisAU: 2.361,
            eccentricity: 0.089,
            inclinationDegrees: 7.14,
            longitudeOfAscendingNodeDegrees: 103.8,
            argumentOfPerihelionDegrees: 151.2,
            renderRadiusAU: 0.008,
            notes: "One of the largest asteroids; visited by NASA's Dawn spacecraft."
        ),
        asteroid(name: "2 Pallas", massKg: 2.04e20, meanRadiusMeters: 256_000, orbitalPeriodYears: 4.62, semiMajorAxisAU: 2.773, eccentricity: 0.23, inclinationDegrees: 34.8, renderRadiusAU: 0.008),
        asteroid(name: "10 Hygiea", massKg: 8.7e19, meanRadiusMeters: 217_000, orbitalPeriodYears: 5.56, semiMajorAxisAU: 3.14, eccentricity: 0.12, inclinationDegrees: 3.8, renderRadiusAU: 0.007),
        asteroid(name: "704 Interamnia", massKg: 3.5e19, meanRadiusMeters: 166_000, orbitalPeriodYears: 5.36, semiMajorAxisAU: 3.06, eccentricity: 0.15, inclinationDegrees: 17.3, renderRadiusAU: 0.006),
        asteroid(name: "3 Juno", massKg: 2.67e19, meanRadiusMeters: 123_000, orbitalPeriodYears: 4.36, semiMajorAxisAU: 2.67, eccentricity: 0.26, inclinationDegrees: 13.0, renderRadiusAU: 0.005),
        asteroid(name: "15 Eunomia", massKg: 3.12e19, meanRadiusMeters: 134_000, orbitalPeriodYears: 4.30, semiMajorAxisAU: 2.64, eccentricity: 0.19, inclinationDegrees: 11.7, renderRadiusAU: 0.005),
        asteroid(name: "16 Psyche", massKg: 2.29e19, meanRadiusMeters: 113_000, orbitalPeriodYears: 5.00, semiMajorAxisAU: 2.92, eccentricity: 0.14, inclinationDegrees: 3.1, renderRadiusAU: 0.005, notes: "Target of NASA's Psyche mission."),
        asteroid(name: "511 Davida", massKg: 4.2e19, meanRadiusMeters: 150_000, orbitalPeriodYears: 5.64, semiMajorAxisAU: 3.17, eccentricity: 0.18, inclinationDegrees: 15.9, renderRadiusAU: 0.006),
        asteroid(name: "52 Europa", massKg: 2.4e19, meanRadiusMeters: 157_000, orbitalPeriodYears: 5.46, semiMajorAxisAU: 3.10, eccentricity: 0.11, inclinationDegrees: 7.5, renderRadiusAU: 0.006),
        asteroid(name: "87 Sylvia", massKg: 1.48e19, meanRadiusMeters: 143_000, orbitalPeriodYears: 6.52, semiMajorAxisAU: 3.49, eccentricity: 0.09, inclinationDegrees: 10.9, renderRadiusAU: 0.005),
        asteroid(name: "624 Hektor", massKg: 7.9e18, meanRadiusMeters: 125_000, orbitalPeriodYears: 11.9, semiMajorAxisAU: 5.22, eccentricity: 0.02, inclinationDegrees: 18.2, renderRadiusAU: 0.005, notes: "Large Jupiter Trojan asteroid."),
        asteroid(name: "433 Eros", massKg: 6.69e15, meanRadiusMeters: 8_400, orbitalPeriodYears: 1.76, semiMajorAxisAU: 1.46, eccentricity: 0.22, inclinationDegrees: 10.8, renderRadiusAU: 0.004, notes: "Near-Earth asteroid visited by NEAR Shoemaker."),
        asteroid(name: "101955 Bennu", massKg: 7.33e10, meanRadiusMeters: 245, orbitalPeriodYears: 1.20, semiMajorAxisAU: 1.126, eccentricity: 0.204, inclinationDegrees: 6.0, renderRadiusAU: 0.003, notes: "OSIRIS-REx sample-return asteroid."),
        asteroid(name: "162173 Ryugu", massKg: 4.5e11, meanRadiusMeters: 450, orbitalPeriodYears: 1.30, semiMajorAxisAU: 1.19, eccentricity: 0.19, inclinationDegrees: 5.9, renderRadiusAU: 0.003, notes: "Hayabusa2 sample-return asteroid."),
        asteroid(name: "25143 Itokawa", massKg: 3.51e10, meanRadiusMeters: 165, orbitalPeriodYears: 1.52, semiMajorAxisAU: 1.32, eccentricity: 0.28, inclinationDegrees: 1.6, renderRadiusAU: 0.003),
        asteroid(name: "99942 Apophis", massKg: 6.1e10, meanRadiusMeters: 185, orbitalPeriodYears: 0.89, semiMajorAxisAU: 0.922, eccentricity: 0.191, inclinationDegrees: 3.3, renderRadiusAU: 0.003, notes: "Near-Earth asteroid with a notable close approach in 2029.")
    ]

    private static func asteroid(
        name: String,
        massKg: Double?,
        meanRadiusMeters: Double?,
        orbitalPeriodYears: Double,
        semiMajorAxisAU: Double,
        eccentricity: Double,
        inclinationDegrees: Double,
        longitudeOfAscendingNodeDegrees: Double? = nil,
        argumentOfPerihelionDegrees: Double? = nil,
        renderRadiusAU: Float,
        notes: String? = nil
    ) -> MinorBodyDefinition {
        MinorBodyDefinition(
            name: name,
            kind: .asteroid,
            massKg: massKg,
            meanRadiusMeters: meanRadiusMeters,
            orbitalPeriodYears: orbitalPeriodYears,
            semiMajorAxisAU: semiMajorAxisAU,
            eccentricity: eccentricity,
            inclinationDegrees: inclinationDegrees,
            longitudeOfAscendingNodeDegrees: longitudeOfAscendingNodeDegrees ?? deterministicDegrees(name: name, salt: 13),
            argumentOfPerihelionDegrees: argumentOfPerihelionDegrees ?? deterministicDegrees(name: name, salt: 47),
            phaseOffsetRadians: deterministicRadians(name: name, salt: 91),
            color: asteroidColor(name: name),
            renderRadiusAU: renderRadiusAU,
            notes: notes
        )
    }

    private static func deterministicDegrees(name: String, salt: Int) -> Double {
        deterministicUnit(name: name, salt: salt) * 360.0
    }

    private static func deterministicRadians(name: String, salt: Int) -> Double {
        deterministicUnit(name: name, salt: salt) * Double.pi * 2.0
    }

    private static func deterministicUnit(name: String, salt: Int) -> Double {
        let scalarSum = name.unicodeScalars.reduce(salt) { $0 &+ Int($1.value) }
        let value = abs(sin(Double(scalarSum) * 12.9898) * 43_758.5453)
        return value - floor(value)
    }

    private static func asteroidColor(name: String) -> SIMD4<Float> {
        let warmth = Float(deterministicUnit(name: name, salt: 151))
        let base = Float(0.42 + deterministicUnit(name: name, salt: 211) * 0.18)
        return SIMD4<Float>(base + warmth * 0.10, base + warmth * 0.05, base, 1)
    }
}

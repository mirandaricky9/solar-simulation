import Foundation
import simd

nonisolated enum CometCatalog {
    static let notableComets: [CometDefinition] = [
        CometDefinition(
            name: "1P/Halley",
            shortName: "Halley",
            periodYears: 76,
            perihelionAU: 0.586,
            eccentricity: 0.967,
            inclinationDegrees: 162.0,
            longitudeOfAscendingNodeDegrees: 59.4,
            argumentOfPerihelionDegrees: 112.0,
            phaseOffsetRadians: 0.35,
            nucleusRadiusAU: 0.018,
            comaRadiusAU: 0.16,
            tailLengthAU: 1.8,
            color: SIMD4<Float>(0.82, 0.92, 1.0, 1)
        ),
        CometDefinition(
            name: "2P/Encke",
            shortName: "Encke",
            periodYears: 3.30,
            perihelionAU: 0.339,
            eccentricity: 0.847,
            inclinationDegrees: 11.3,
            longitudeOfAscendingNodeDegrees: 334.0,
            argumentOfPerihelionDegrees: 187.3,
            phaseOffsetRadians: 2.1,
            nucleusRadiusAU: 0.010,
            comaRadiusAU: 0.09,
            tailLengthAU: 0.85,
            color: SIMD4<Float>(0.78, 0.88, 1.0, 1)
        ),
        CometDefinition(
            name: "109P/Swift-Tuttle",
            shortName: "Swift-Tuttle",
            periodYears: 133,
            perihelionAU: 0.96,
            eccentricity: 0.963,
            inclinationDegrees: 113.5,
            longitudeOfAscendingNodeDegrees: 139.4,
            argumentOfPerihelionDegrees: 153.0,
            phaseOffsetRadians: 4.4,
            nucleusRadiusAU: 0.020,
            comaRadiusAU: 0.15,
            tailLengthAU: 1.5,
            color: SIMD4<Float>(0.86, 0.93, 1.0, 1)
        ),
        CometDefinition(
            name: "67P/Churyumov-Gerasimenko",
            shortName: "67P",
            periodYears: 6.45,
            perihelionAU: 1.21,
            eccentricity: 0.65,
            inclinationDegrees: 3.9,
            longitudeOfAscendingNodeDegrees: 36.3,
            argumentOfPerihelionDegrees: 22.1,
            phaseOffsetRadians: 1.25,
            nucleusRadiusAU: 0.012,
            comaRadiusAU: 0.075,
            tailLengthAU: 0.55,
            color: SIMD4<Float>(0.76, 0.84, 0.92, 1)
        ),
        CometDefinition(
            name: "9P/Tempel 1",
            shortName: "Tempel 1",
            periodYears: 5.6,
            perihelionAU: 1.54,
            eccentricity: 0.51,
            inclinationDegrees: 10.5,
            longitudeOfAscendingNodeDegrees: 68.6,
            argumentOfPerihelionDegrees: 179.5,
            phaseOffsetRadians: 3.3,
            nucleusRadiusAU: 0.011,
            comaRadiusAU: 0.06,
            tailLengthAU: 0.45,
            color: SIMD4<Float>(0.80, 0.86, 0.94, 1)
        ),
        CometDefinition(
            name: "81P/Wild 2",
            shortName: "Wild 2",
            periodYears: 6.41,
            perihelionAU: 1.60,
            eccentricity: 0.538,
            inclinationDegrees: 3.2,
            longitudeOfAscendingNodeDegrees: 136.1,
            argumentOfPerihelionDegrees: 41.6,
            phaseOffsetRadians: 5.0,
            nucleusRadiusAU: 0.010,
            comaRadiusAU: 0.055,
            tailLengthAU: 0.42,
            color: SIMD4<Float>(0.78, 0.86, 0.95, 1)
        ),
        CometDefinition(
            name: "103P/Hartley 2",
            shortName: "Hartley 2",
            periodYears: 6.48,
            perihelionAU: 1.06,
            eccentricity: 0.693,
            inclinationDegrees: 13.6,
            longitudeOfAscendingNodeDegrees: 219.8,
            argumentOfPerihelionDegrees: 181.3,
            phaseOffsetRadians: 0.9,
            nucleusRadiusAU: 0.008,
            comaRadiusAU: 0.07,
            tailLengthAU: 0.62,
            color: SIMD4<Float>(0.80, 0.91, 1.0, 1)
        ),
        CometDefinition(
            name: "C/1995 O1 Hale-Bopp",
            shortName: "Hale-Bopp",
            periodYears: 2434,
            perihelionAU: 0.92,
            eccentricity: 0.995,
            inclinationDegrees: 89.8,
            longitudeOfAscendingNodeDegrees: 281.8,
            argumentOfPerihelionDegrees: 130.7,
            phaseOffsetRadians: 2.75,
            nucleusRadiusAU: 0.026,
            comaRadiusAU: 0.22,
            tailLengthAU: 2.4,
            color: SIMD4<Float>(0.90, 0.95, 1.0, 1)
        ),
        CometDefinition(
            name: "C/1996 B2 Hyakutake",
            shortName: "Hyakutake",
            periodYears: 70_000,
            perihelionAU: 0.23,
            eccentricity: 0.99989,
            inclinationDegrees: 124.9,
            longitudeOfAscendingNodeDegrees: 188.0,
            argumentOfPerihelionDegrees: 130.2,
            phaseOffsetRadians: 5.65,
            nucleusRadiusAU: 0.016,
            comaRadiusAU: 0.19,
            tailLengthAU: 2.8,
            color: SIMD4<Float>(0.84, 0.94, 1.0, 1)
        ),
        CometDefinition(
            name: "C/2020 F3 NEOWISE",
            shortName: "NEOWISE",
            periodYears: 6_800,
            perihelionAU: 0.295,
            eccentricity: 0.9992,
            inclinationDegrees: 128.9,
            longitudeOfAscendingNodeDegrees: 61.0,
            argumentOfPerihelionDegrees: 37.3,
            phaseOffsetRadians: 1.8,
            nucleusRadiusAU: 0.015,
            comaRadiusAU: 0.17,
            tailLengthAU: 2.2,
            color: SIMD4<Float>(0.86, 0.94, 1.0, 1)
        ),
        CometDefinition(
            name: "C/2006 P1 McNaught",
            shortName: "McNaught",
            periodYears: 92_600,
            perihelionAU: 0.17,
            eccentricity: 0.99917,
            inclinationDegrees: 77.8,
            longitudeOfAscendingNodeDegrees: 267.4,
            argumentOfPerihelionDegrees: 156.0,
            phaseOffsetRadians: 4.95,
            nucleusRadiusAU: 0.018,
            comaRadiusAU: 0.20,
            tailLengthAU: 3.0,
            color: SIMD4<Float>(0.92, 0.96, 1.0, 1)
        ),
        comet(name: "19P/Borrelly", shortName: "Borrelly", periodYears: 6.85, perihelionAU: 1.36, eccentricity: 0.62, inclinationDegrees: 30.3),
        comet(name: "21P/Giacobini-Zinner", shortName: "Giacobini-Zinner", periodYears: 6.52, perihelionAU: 1.01, eccentricity: 0.71, inclinationDegrees: 32.0, notes: "Parent of the Draconid meteor shower."),
        comet(name: "26P/Grigg-Skjellerup", shortName: "Grigg-Skjellerup", periodYears: 5.31, perihelionAU: 1.12, eccentricity: 0.64, inclinationDegrees: 22.4),
        comet(name: "46P/Wirtanen", shortName: "Wirtanen", periodYears: 5.44, perihelionAU: 1.06, eccentricity: 0.66, inclinationDegrees: 11.7),
        comet(name: "55P/Tempel-Tuttle", shortName: "Tempel-Tuttle", periodYears: 33.2, perihelionAU: 0.98, eccentricity: 0.91, inclinationDegrees: 162.5, notes: "Parent of the Leonid meteor shower."),
        comet(name: "73P/Schwassmann-Wachmann 3", shortName: "73P", periodYears: 5.36, perihelionAU: 0.97, eccentricity: 0.69, inclinationDegrees: 11.4),
        comet(name: "96P/Machholz", shortName: "Machholz", periodYears: 5.29, perihelionAU: 0.12, eccentricity: 0.96, inclinationDegrees: 58.3),
        comet(name: "153P/Ikeya-Zhang", shortName: "Ikeya-Zhang", periodYears: 366, perihelionAU: 0.51, eccentricity: 0.99, inclinationDegrees: 28.1),
        comet(name: "C/2011 L4 PANSTARRS", shortName: "PANSTARRS", periodYears: 106_000, perihelionAU: 0.30, eccentricity: 0.999, inclinationDegrees: 84.2),
        comet(name: "C/2012 S1 ISON", shortName: "ISON", periodYears: 400_000, perihelionAU: 0.012, eccentricity: 0.9999, inclinationDegrees: 62.4, notes: "Sungrazing comet that disintegrated near perihelion."),
        comet(name: "C/2021 A1 Leonard", shortName: "Leonard", periodYears: 80_000, perihelionAU: 0.62, eccentricity: 0.999, inclinationDegrees: 132.7),
        comet(name: "C/2023 P1 Nishimura", shortName: "Nishimura", periodYears: 430, perihelionAU: 0.23, eccentricity: 0.996, inclinationDegrees: 132.5)
    ]

    private static func comet(
        name: String,
        shortName: String,
        periodYears: Double,
        perihelionAU: Double,
        eccentricity: Double,
        inclinationDegrees: Double,
        notes: String? = nil
    ) -> CometDefinition {
        CometDefinition(
            name: name,
            shortName: shortName,
            periodYears: periodYears,
            perihelionAU: perihelionAU,
            eccentricity: eccentricity,
            inclinationDegrees: inclinationDegrees,
            longitudeOfAscendingNodeDegrees: deterministicDegrees(name: name, salt: 19),
            argumentOfPerihelionDegrees: deterministicDegrees(name: name, salt: 71),
            phaseOffsetRadians: deterministicRadians(name: name, salt: 127),
            nucleusRadiusAU: periodYears > 100 ? 0.016 : 0.010,
            comaRadiusAU: periodYears > 100 ? 0.16 : 0.075,
            tailLengthAU: perihelionAU < 0.3 ? 2.4 : 0.75,
            color: SIMD4<Float>(0.84, 0.93, 1.0, 1),
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
}

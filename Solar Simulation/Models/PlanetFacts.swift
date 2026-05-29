import Foundation

struct PlanetFacts: Sendable {
    let name: String
    let orbitalPeriodYears: Double
    let rotationPeriodHours: Double
    let lengthOfDayHours: Double
    let axialTiltDegrees: Double

    var orbitalPeriodSeconds: Double {
        orbitalPeriodYears * SolarSystemConstants.secondsPerJulianYear
    }

    var rotationPeriodSeconds: Double {
        abs(rotationPeriodHours) * 3_600.0
    }

    var isRetrogradeRotation: Bool {
        rotationPeriodHours < 0
    }

    var rotationDirection: String {
        isRetrogradeRotation ? "Retrograde" : "Prograde"
    }
}

enum PlanetFactCatalog {
    static let planetNames = [
        "Mercury", "Venus", "Earth", "Mars",
        "Jupiter", "Saturn", "Uranus", "Neptune"
    ]

    static let byName: [String: PlanetFacts] = [
        "Mercury": PlanetFacts(
            name: "Mercury",
            orbitalPeriodYears: 0.2408467,
            rotationPeriodHours: 1_407.6,
            lengthOfDayHours: 4_222.6,
            axialTiltDegrees: 0.034
        ),
        "Venus": PlanetFacts(
            name: "Venus",
            orbitalPeriodYears: 0.61519726,
            rotationPeriodHours: -5_832.5,
            lengthOfDayHours: 2_802.0,
            axialTiltDegrees: 177.36
        ),
        "Earth": PlanetFacts(
            name: "Earth",
            orbitalPeriodYears: 1.0000174,
            rotationPeriodHours: 23.9345,
            lengthOfDayHours: 24.0,
            axialTiltDegrees: 23.44
        ),
        "Mars": PlanetFacts(
            name: "Mars",
            orbitalPeriodYears: 1.8808476,
            rotationPeriodHours: 24.6229,
            lengthOfDayHours: 24.6597,
            axialTiltDegrees: 25.19
        ),
        "Jupiter": PlanetFacts(
            name: "Jupiter",
            orbitalPeriodYears: 11.862615,
            rotationPeriodHours: 9.925,
            lengthOfDayHours: 9.925,
            axialTiltDegrees: 3.13
        ),
        "Saturn": PlanetFacts(
            name: "Saturn",
            orbitalPeriodYears: 29.447498,
            rotationPeriodHours: 10.656,
            lengthOfDayHours: 10.656,
            axialTiltDegrees: 26.73
        ),
        "Uranus": PlanetFacts(
            name: "Uranus",
            orbitalPeriodYears: 84.016846,
            rotationPeriodHours: -17.24,
            lengthOfDayHours: 17.24,
            axialTiltDegrees: 97.77
        ),
        "Neptune": PlanetFacts(
            name: "Neptune",
            orbitalPeriodYears: 164.79132,
            rotationPeriodHours: 16.11,
            lengthOfDayHours: 16.11,
            axialTiltDegrees: 28.32
        )
    ]
}

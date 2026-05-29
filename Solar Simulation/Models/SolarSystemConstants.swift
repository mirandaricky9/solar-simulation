import Foundation

nonisolated enum SolarSystemConstants {
    static let G: Double = 6.67430e-11
    static let solarMass: Double = 1.989e30
    static let astronomicalUnit: Double = 149_597_870_700
    static let baseTimeStep: Double = 3_600
    static let secondsPerJulianYear: Double = 365.25 * 86_400.0

    static func yearsToSeconds(_ years: Double) -> Double {
        years * secondsPerJulianYear
    }

    static func siderealOrbitalPeriodSeconds(forPlanetNamed name: String) -> Double? {
        PlanetFactCatalog.byName[name]?.orbitalPeriodSeconds
    }
}

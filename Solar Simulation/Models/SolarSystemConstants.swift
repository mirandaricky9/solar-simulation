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
        switch name {
        case "Mercury":
            return yearsToSeconds(0.2408467)
        case "Venus":
            return yearsToSeconds(0.61519726)
        case "Earth":
            return yearsToSeconds(1.0000174)
        case "Mars":
            return yearsToSeconds(1.8808476)
        case "Jupiter":
            return yearsToSeconds(11.862615)
        case "Saturn":
            return yearsToSeconds(29.447498)
        case "Uranus":
            return yearsToSeconds(84.016846)
        case "Neptune":
            return yearsToSeconds(164.79132)
        default:
            return nil
        }
    }
}

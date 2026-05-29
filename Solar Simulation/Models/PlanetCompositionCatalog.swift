import Foundation

struct BodyCompositionFacts: Sendable {
    let bodyClass: String
    let primaryComposition: String
    let sourceNote: String?
}

enum PlanetCompositionCatalog {
    static let byName: [String: BodyCompositionFacts] = [
        "Sun": BodyCompositionFacts(bodyClass: "Star", primaryComposition: "mostly hydrogen and helium plasma", sourceNote: nil),
        "Mercury": BodyCompositionFacts(bodyClass: "Terrestrial / rocky planet", primaryComposition: "silicate rock and metal", sourceNote: nil),
        "Venus": BodyCompositionFacts(bodyClass: "Terrestrial / rocky planet", primaryComposition: "silicate rock and metal; dense CO2 atmosphere", sourceNote: nil),
        "Earth": BodyCompositionFacts(bodyClass: "Terrestrial / rocky planet", primaryComposition: "silicate rock, metal core, surface water", sourceNote: nil),
        "Mars": BodyCompositionFacts(bodyClass: "Terrestrial / rocky planet", primaryComposition: "silicate rock and iron-rich minerals", sourceNote: nil),
        "Jupiter": BodyCompositionFacts(bodyClass: "Gas giant", primaryComposition: "mostly hydrogen and helium", sourceNote: "Reference surface area uses mean radius; Jupiter has no solid surface."),
        "Saturn": BodyCompositionFacts(bodyClass: "Gas giant", primaryComposition: "mostly hydrogen and helium", sourceNote: "Reference surface area uses mean radius; Saturn has no solid surface."),
        "Uranus": BodyCompositionFacts(bodyClass: "Ice giant", primaryComposition: "water, ammonia, methane ices plus hydrogen/helium atmosphere", sourceNote: "Reference surface area uses mean radius; Uranus has no solid surface."),
        "Neptune": BodyCompositionFacts(bodyClass: "Ice giant", primaryComposition: "water, ammonia, methane ices plus hydrogen/helium atmosphere", sourceNote: "Reference surface area uses mean radius; Neptune has no solid surface."),
        "Moon": BodyCompositionFacts(bodyClass: "Natural satellite", primaryComposition: "silicate rock", sourceNote: nil),
        "Pluto": BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "rock and water ice with volatile surface ices", sourceNote: nil),
        "Ceres": BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "hydrated minerals, rock, and ice", sourceNote: nil),
        "Haumea": BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "rocky body with water-ice surface", sourceNote: nil),
        "Makemake": BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "methane, ethane, and nitrogen ices over rock/ice body", sourceNote: nil),
        "Eris": BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "rock and ice with methane-rich surface frost", sourceNote: nil),
        "Asteroid Belt": BodyCompositionFacts(bodyClass: "Asteroid belt", primaryComposition: "rocky and metallic minor bodies", sourceNote: "Visual-only field; not N-body simulated."),
        "Kuiper Belt": BodyCompositionFacts(bodyClass: "Trans-Neptunian belt", primaryComposition: "icy bodies rich in water, methane, ammonia, and other volatiles", sourceNote: "Visual-only field; not N-body simulated."),
        "Oort Cloud": BodyCompositionFacts(bodyClass: "Theoretical comet cloud", primaryComposition: "distant icy comet nuclei", sourceNote: "Theoretical visual shell; not N-body simulated.")
    ]

    static func fallback(for kind: CelestialObjectKind) -> BodyCompositionFacts? {
        switch kind {
        case .moon:
            return BodyCompositionFacts(bodyClass: "Natural satellite", primaryComposition: "rock and ice mixture", sourceNote: nil)
        case .dwarfPlanet:
            return BodyCompositionFacts(bodyClass: "Dwarf planet", primaryComposition: "rock and ice mixture", sourceNote: nil)
        case .asteroid:
            return BodyCompositionFacts(bodyClass: "Asteroid", primaryComposition: "rocky, metallic, or carbon-rich material", sourceNote: nil)
        case .comet:
            return BodyCompositionFacts(bodyClass: "Comet", primaryComposition: "ice, dust, and rocky material", sourceNote: "Analytic visual comet; not N-body simulated.")
        case .asteroidBelt:
            return byName["Asteroid Belt"]
        case .kuiperBelt:
            return byName["Kuiper Belt"]
        case .oortCloud:
            return byName["Oort Cloud"]
        default:
            return nil
        }
    }
}

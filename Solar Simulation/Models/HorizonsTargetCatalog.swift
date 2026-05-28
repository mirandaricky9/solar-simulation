import Foundation

struct HorizonsTargetDefinition: Codable, Hashable, Sendable {
    let name: String
    let horizonsCommand: String
    let kind: CelestialObjectKind
    let parentName: String?
    let isPhysicsBody: Bool
}

enum HorizonsTargetCatalog {
    static let targets: [HorizonsTargetDefinition] = [
        HorizonsTargetDefinition(name: "Sun", horizonsCommand: "10", kind: .star, parentName: nil, isPhysicsBody: true),

        HorizonsTargetDefinition(name: "Mercury", horizonsCommand: "199", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Venus", horizonsCommand: "299", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Earth", horizonsCommand: "399", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Mars", horizonsCommand: "499", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Jupiter", horizonsCommand: "599", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Saturn", horizonsCommand: "699", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Uranus", horizonsCommand: "799", kind: .planet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Neptune", horizonsCommand: "899", kind: .planet, parentName: nil, isPhysicsBody: true),

        HorizonsTargetDefinition(name: "Moon", horizonsCommand: "301", kind: .moon, parentName: "Earth", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Phobos", horizonsCommand: "401", kind: .moon, parentName: "Mars", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Deimos", horizonsCommand: "402", kind: .moon, parentName: "Mars", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Io", horizonsCommand: "501", kind: .moon, parentName: "Jupiter", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Europa", horizonsCommand: "502", kind: .moon, parentName: "Jupiter", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Ganymede", horizonsCommand: "503", kind: .moon, parentName: "Jupiter", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Callisto", horizonsCommand: "504", kind: .moon, parentName: "Jupiter", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Mimas", horizonsCommand: "601", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Enceladus", horizonsCommand: "602", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Tethys", horizonsCommand: "603", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Dione", horizonsCommand: "604", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Rhea", horizonsCommand: "605", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Titan", horizonsCommand: "606", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Hyperion", horizonsCommand: "607", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Iapetus", horizonsCommand: "608", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Phoebe", horizonsCommand: "609", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Janus", horizonsCommand: "610", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Epimetheus", horizonsCommand: "611", kind: .moon, parentName: "Saturn", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Ariel", horizonsCommand: "701", kind: .moon, parentName: "Uranus", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Umbriel", horizonsCommand: "702", kind: .moon, parentName: "Uranus", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Titania", horizonsCommand: "703", kind: .moon, parentName: "Uranus", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Oberon", horizonsCommand: "704", kind: .moon, parentName: "Uranus", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Miranda", horizonsCommand: "705", kind: .moon, parentName: "Uranus", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Triton", horizonsCommand: "801", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Nereid", horizonsCommand: "802", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Naiad", horizonsCommand: "803", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Thalassa", horizonsCommand: "804", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Despina", horizonsCommand: "805", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Galatea", horizonsCommand: "806", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Larissa", horizonsCommand: "807", kind: .moon, parentName: "Neptune", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Proteus", horizonsCommand: "808", kind: .moon, parentName: "Neptune", isPhysicsBody: true),

        HorizonsTargetDefinition(name: "Pluto", horizonsCommand: "999", kind: .dwarfPlanet, parentName: nil, isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Charon", horizonsCommand: "901", kind: .moon, parentName: "Pluto", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Nix", horizonsCommand: "902", kind: .moon, parentName: "Pluto", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Hydra", horizonsCommand: "903", kind: .moon, parentName: "Pluto", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Kerberos", horizonsCommand: "904", kind: .moon, parentName: "Pluto", isPhysicsBody: true),
        HorizonsTargetDefinition(name: "Styx", horizonsCommand: "905", kind: .moon, parentName: "Pluto", isPhysicsBody: true),

        HorizonsTargetDefinition(name: "Ceres", horizonsCommand: "1;", kind: .dwarfPlanet, parentName: nil, isPhysicsBody: false),
        HorizonsTargetDefinition(name: "Vesta", horizonsCommand: "4;", kind: .asteroid, parentName: nil, isPhysicsBody: false),
        HorizonsTargetDefinition(name: "Pallas", horizonsCommand: "2;", kind: .asteroid, parentName: nil, isPhysicsBody: false),
        HorizonsTargetDefinition(name: "Hygiea", horizonsCommand: "10;", kind: .asteroid, parentName: nil, isPhysicsBody: false),

        HorizonsTargetDefinition(name: "1P/Halley", horizonsCommand: "DES=1P;CAP;NOFRAG", kind: .comet, parentName: nil, isPhysicsBody: false),
        HorizonsTargetDefinition(name: "2P/Encke", horizonsCommand: "DES=2P;CAP;NOFRAG", kind: .comet, parentName: nil, isPhysicsBody: false),
        HorizonsTargetDefinition(name: "109P/Swift-Tuttle", horizonsCommand: "DES=109P;CAP;NOFRAG", kind: .comet, parentName: nil, isPhysicsBody: false)
    ]
}

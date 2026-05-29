import Foundation

struct RotationFacts: Sendable {
    let rotationPeriodHours: Double?
    let axialTiltDegrees: Double?
    let isRetrograde: Bool
    let sourceNote: String

    var rotationPeriodSeconds: Double? {
        guard let rotationPeriodHours else { return nil }
        return abs(rotationPeriodHours) * 3_600.0
    }

    var rotationDirection: String {
        isRetrograde ? "Retrograde" : "Prograde"
    }
}

enum RotationFactCatalog {
    static let byName: [String: RotationFacts] = makeFacts()

    private static func makeFacts() -> [String: RotationFacts] {
        var facts: [String: RotationFacts] = [:]

        for (name, planetFacts) in PlanetFactCatalog.byName {
            facts[name] = RotationFacts(
                rotationPeriodHours: planetFacts.rotationPeriodHours,
                axialTiltDegrees: planetFacts.axialTiltDegrees,
                isRetrograde: planetFacts.isRetrogradeRotation,
                sourceNote: "NASA Planetary Fact Sheet style rotation and axial tilt values."
            )
        }

        facts["Moon"] = synchronous(periodDays: 27.3217, axialTiltDegrees: 6.68)
        facts["Phobos"] = synchronous(periodDays: 0.3189)
        facts["Deimos"] = synchronous(periodDays: 1.263)
        facts["Io"] = synchronous(periodDays: 1.769)
        facts["Europa"] = synchronous(periodDays: 3.551)
        facts["Ganymede"] = synchronous(periodDays: 7.155)
        facts["Callisto"] = synchronous(periodDays: 16.689)
        facts["Mimas"] = synchronous(periodDays: 0.942)
        facts["Enceladus"] = synchronous(periodDays: 1.370)
        facts["Tethys"] = synchronous(periodDays: 1.888)
        facts["Dione"] = synchronous(periodDays: 2.737)
        facts["Rhea"] = synchronous(periodDays: 4.518)
        facts["Titan"] = synchronous(periodDays: 15.945)
        facts["Iapetus"] = synchronous(periodDays: 79.33)
        facts["Hyperion"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Chaotic rotation; spin is not currently modeled.")
        facts["Janus"] = synchronous(periodDays: 0.695)
        facts["Epimetheus"] = synchronous(periodDays: 0.694)
        facts["Miranda"] = synchronous(periodDays: 1.413)
        facts["Ariel"] = synchronous(periodDays: 2.520)
        facts["Umbriel"] = synchronous(periodDays: 4.144)
        facts["Titania"] = synchronous(periodDays: 8.706)
        facts["Oberon"] = synchronous(periodDays: 13.463)
        facts["Triton"] = synchronous(periodDays: 5.877, isRetrograde: true)
        facts["Nereid"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Irregular moon; rotation period is not currently modeled.")
        facts["Proteus"] = synchronous(periodDays: 1.122)
        facts["Larissa"] = synchronous(periodDays: 0.555)
        facts["Galatea"] = synchronous(periodDays: 0.429)
        facts["Despina"] = synchronous(periodDays: 0.335)
        facts["Thalassa"] = synchronous(periodDays: 0.312)
        facts["Naiad"] = synchronous(periodDays: 0.294)
        facts["Charon"] = synchronous(periodDays: 6.387, isRetrograde: true)
        facts["Nix"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Small Pluto moon; rotation period is not currently modeled.")
        facts["Hydra"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Small Pluto moon; rotation period is not currently modeled.")
        facts["Kerberos"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Small Pluto moon; rotation period is not currently modeled.")
        facts["Styx"] = RotationFacts(rotationPeriodHours: nil, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Small Pluto moon; rotation period is not currently modeled.")

        facts["Pluto"] = RotationFacts(rotationPeriodHours: 153.3, axialTiltDegrees: 119.6, isRetrograde: true, sourceNote: "Approximate dwarf-planet rotation value.")
        facts["Ceres"] = RotationFacts(rotationPeriodHours: 9.07, axialTiltDegrees: 4.0, isRetrograde: false, sourceNote: "Approximate dwarf-planet rotation value.")
        facts["Haumea"] = RotationFacts(rotationPeriodHours: 3.92, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate dwarf-planet rotation value.")
        facts["Makemake"] = RotationFacts(rotationPeriodHours: 22.8, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate dwarf-planet rotation value.")
        facts["Eris"] = RotationFacts(rotationPeriodHours: 379.2, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate dwarf-planet rotation value; not dynamically modeled.")

        facts["4 Vesta"] = RotationFacts(rotationPeriodHours: 5.34, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")
        facts["433 Eros"] = RotationFacts(rotationPeriodHours: 5.27, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")
        facts["101955 Bennu"] = RotationFacts(rotationPeriodHours: 4.30, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")
        facts["162173 Ryugu"] = RotationFacts(rotationPeriodHours: 7.63, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")
        facts["25143 Itokawa"] = RotationFacts(rotationPeriodHours: 12.13, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")
        facts["99942 Apophis"] = RotationFacts(rotationPeriodHours: 30.4, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate asteroid rotation value.")

        facts["1P/Halley"] = RotationFacts(rotationPeriodHours: 52.8, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate comet nucleus rotation value.")
        facts["67P/Churyumov-Gerasimenko"] = RotationFacts(rotationPeriodHours: 12.4, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate comet nucleus rotation value.")
        facts["9P/Tempel 1"] = RotationFacts(rotationPeriodHours: 41.0, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate comet nucleus rotation value.")
        facts["103P/Hartley 2"] = RotationFacts(rotationPeriodHours: 18.0, axialTiltDegrees: nil, isRetrograde: false, sourceNote: "Approximate comet nucleus rotation value.")

        return facts
    }

    private static func synchronous(
        periodDays: Double,
        axialTiltDegrees: Double? = nil,
        isRetrograde: Bool = false
    ) -> RotationFacts {
        RotationFacts(
            rotationPeriodHours: periodDays * 24.0,
            axialTiltDegrees: axialTiltDegrees,
            isRetrograde: isRetrograde,
            sourceNote: "Synchronous rotation / tidally locked approximation."
        )
    }
}

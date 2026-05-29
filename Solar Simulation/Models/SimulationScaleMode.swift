import Foundation

enum SimulationScaleMode: String, CaseIterable, Identifiable {
    case enhanced = "Enhanced"
    case trueScale = "True Scale"

    var id: String { rawValue }
}

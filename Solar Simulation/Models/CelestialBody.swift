import Foundation
import simd

struct CelestialBody: Identifiable {
    let id = UUID()
    let name: String
    let mass: Double
    let visualRadius: Double
    let initialPosition: SIMD3<Double>
    let initialVelocity: SIMD3<Double>
    let isStar: Bool
    let isMoon: Bool
    let isAsteroid: Bool
    let color: SIMD4<Float>

    var position: SIMD3<Double>
    var velocity: SIMD3<Double>
    var cumulativePosition: [SIMD3<Double>] = []

    init(
        name: String,
        mass: Double,
        visualRadius: Double,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        color: SIMD4<Float>,
        isStar: Bool = false,
        isMoon: Bool = false,
        isAsteroid: Bool = false
    ) {
        self.name = name
        self.mass = mass
        self.visualRadius = visualRadius
        self.initialPosition = position
        self.initialVelocity = velocity
        self.position = position
        self.velocity = velocity
        self.color = color
        self.isStar = isStar
        self.isMoon = isMoon
        self.isAsteroid = isAsteroid
    }
}

import Foundation
import MetalKit
import simd

private struct SphereVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

private struct BodyInstance {
    var positionRadius: SIMD4<Float>
    var color: SIMD4<Float>
    var material: SIMD4<Float>
}

private struct PathVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct Uniforms {
    var viewProjectionMatrix: simd_float4x4
    var lightPosition: SIMD4<Float>
    var cameraPosition: SIMD4<Float>
}

private struct MeshResource {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var indexCount: Int
}

private enum ScaleMode {
    case compact
    case balanced
    case realisticDistances
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    private static let defaultCameraPosition = SIMD3<Float>(0, 0, 80)
    private static let defaultYaw: Float = 0
    private static let defaultPitch: Float = -Float.pi / 2
    private static let dynamicBufferCount = 3
    private static let asteroidVariantCount = 12

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bodyPipelineState: MTLRenderPipelineState
    private let pathPipelineState: MTLRenderPipelineState
    private let bodyDepthStencilState: MTLDepthStencilState
    private let pathDepthStencilState: MTLDepthStencilState

    private weak var mtkView: MTKView?
    private weak var viewModel: SimulationViewModel?

    private var highDetailSphereVertexBuffer: MTLBuffer?
    private var highDetailSphereIndexBuffer: MTLBuffer?
    private var highDetailSphereIndexCount = 0

    private var asteroidMeshVariants: [MeshResource] = []

    private var majorBodyInstanceBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var majorBodyInstanceCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var majorBodyInstanceCount = 0

    private var asteroidVariantInstanceBuffers = Array(
        repeating: Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var asteroidVariantInstanceCapacities = Array(
        repeating: Array(repeating: 0, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var asteroidVariantInstanceCounts = Array(repeating: 0, count: MetalRenderer.asteroidVariantCount)

    private var pathVertexBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var pathVertexCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var pathVertexCount = 0

    private var staticOrbitVertexBuffer: MTLBuffer?
    private var staticOrbitVertexCapacity = 0
    private var staticOrbitVertexCount = 0
    private var staticOrbitSignature: [UUID] = []

    private var dynamicBufferIndex = 0

    private var currentBodies: [CelestialBody] = []
    private var worldViewProjectionMatrix = matrix_identity_float4x4
    private var lightPosition = SIMD3<Float>(0, 0, 0)

    private var cameraPosition = MetalRenderer.defaultCameraPosition
    private var yaw = MetalRenderer.defaultYaw
    private var pitch = MetalRenderer.defaultPitch
    private var roll: Float = 0
    private var zoom: Float = 1.0
    private var lastFrameTime = Date()

    private let fieldOfViewRadians: Float = Float.pi / 4
    private let minimumZoomScale: Float = 1.0e-6
    private let minimumFieldOfViewRadians: Float = Float.pi / 100_000
    private let maximumFieldOfViewRadians: Float = Float.pi * 0.999
    private let lookSensitivity: Float = 0.006
    private let keyboardLookSpeed: Float = 1.25
    private let keyboardRollSpeed: Float = 1.35
    private let movementSpeed: Float = 24.0
    private let minimumCameraSensitivity: Float = 0.05
    private let maximumCameraSensitivity: Float = 1.0
    private let maximumMovementDeltaTime: Float = 1.0 / 15.0
    private let minimumPitch: Float = -Float.pi / 2
    private let maximumPitch: Float = Float.pi / 2

    private var bodySizeMultiplier: Float = 1.0
    private var cameraSensitivityMultiplier: Float = 1.0
    private let scaleMode: ScaleMode = .balanced

    private let sunVisualRadiusAU: Float = 0.08
    private let minimumPlanetVisualRadiusAU: Float = 0.012
    private let moonVisualRadiusAU: Float = 0.006
    private let asteroidVisualRadiusAU: Float = 0.0025
    private let planetRadiusScale: Float = 0.08
    private let moonRadiusScale: Float = 0.06
    private let compactScaleMultiplier: Float = 1.35
    private let realisticScaleMultiplier: Float = 0.45
    private let zoomRadiusFalloff: Float = 0.08
    private let orbitRingSegmentCount = 512

    init(mtkView: MTKView, viewModel: SimulationViewModel) {
        guard let device = mtkView.device else {
            fatalError("MTKView has no Metal device.")
        }

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue.")
        }

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load the default Metal shader library. Make sure Shaders.metal is included in the app target.")
        }

        guard let bodyVertexFunction = library.makeFunction(name: "bodyVertexShader"),
              let bodyFragmentFunction = library.makeFunction(name: "bodyFragmentShader"),
              let pathVertexFunction = library.makeFunction(name: "pathVertexShader"),
              let pathFragmentFunction = library.makeFunction(name: "pathFragmentShader") else {
            fatalError("Could not find one or more Metal shader functions.")
        }

        let bodyPipelineDescriptor = MTLRenderPipelineDescriptor()
        bodyPipelineDescriptor.label = "3D Body Pipeline"
        bodyPipelineDescriptor.vertexFunction = bodyVertexFunction
        bodyPipelineDescriptor.fragmentFunction = bodyFragmentFunction
        bodyPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        bodyPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        let pathPipelineDescriptor = MTLRenderPipelineDescriptor()
        pathPipelineDescriptor.label = "3D Path Pipeline"
        pathPipelineDescriptor.vertexFunction = pathVertexFunction
        pathPipelineDescriptor.fragmentFunction = pathFragmentFunction
        pathPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pathPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pathPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pathPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pathPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pathPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pathPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pathPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pathPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        do {
            self.bodyPipelineState = try device.makeRenderPipelineState(descriptor: bodyPipelineDescriptor)
            self.pathPipelineState = try device.makeRenderPipelineState(descriptor: pathPipelineDescriptor)
        } catch {
            fatalError("Could not create Metal render pipeline states: \(error)")
        }

        let bodyDepthDescriptor = MTLDepthStencilDescriptor()
        bodyDepthDescriptor.depthCompareFunction = .lessEqual
        bodyDepthDescriptor.isDepthWriteEnabled = true

        guard let bodyDepthStencilState = device.makeDepthStencilState(descriptor: bodyDepthDescriptor) else {
            fatalError("Could not create body depth stencil state.")
        }

        let pathDepthDescriptor = MTLDepthStencilDescriptor()
        pathDepthDescriptor.depthCompareFunction = .lessEqual
        pathDepthDescriptor.isDepthWriteEnabled = false

        guard let pathDepthStencilState = device.makeDepthStencilState(descriptor: pathDepthDescriptor) else {
            fatalError("Could not create path depth stencil state.")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.bodyDepthStencilState = bodyDepthStencilState
        self.pathDepthStencilState = pathDepthStencilState
        self.mtkView = mtkView
        self.viewModel = viewModel

        super.init()

        print("Using Metal device: \(device.name)")
        let highDetailSphere = createSphereMesh(
            latitudeSegments: 24,
            longitudeSegments: 48,
            vertexBufferLabel: "High Detail Sphere Vertex Buffer",
            indexBufferLabel: "High Detail Sphere Index Buffer"
        )
        highDetailSphereVertexBuffer = highDetailSphere.vertexBuffer
        highDetailSphereIndexBuffer = highDetailSphere.indexBuffer
        highDetailSphereIndexCount = highDetailSphere.indexCount

        asteroidMeshVariants = (0..<Self.asteroidVariantCount).map { variant in
            createIrregularAsteroidMesh(
                latitudeSegments: 5,
                longitudeSegments: 10,
                seed: 0xA511_E901_D00D_0000 &+ UInt64(variant)
            )
        }

        calculateProjectionMatrix(drawableSize: mtkView.drawableSize)
        updateBodies(viewModel.bodies)
    }

    func updateBodies(_ bodies: [CelestialBody]) {
        currentBodies = bodies
        rebuildBodyInstanceBuffer(from: bodies)
        rebuildStaticOrbitBufferIfNeeded(from: bodies)
        rebuildPathBuffer(from: bodies)
    }

    func setZoom(_ newZoom: Float) {
        guard newZoom.isFinite else { return }

        zoom = max(newZoom, minimumZoomScale)
        recalculateProjectionForCurrentView()
        rebuildBodyInstanceBuffer(from: currentBodies)
    }

    func zoomBy(_ factor: Float) {
        guard factor.isFinite, factor > 0 else { return }

        setZoom(zoom * factor)
    }

    func panBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        lookBy(screenDeltaX: dx, screenDeltaY: dy)
    }

    func lookBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        let sensitivity = lookSensitivity * cameraSensitivityMultiplier
        yaw += dx * sensitivity
        pitch = min(max(pitch + dy * sensitivity, minimumPitch), maximumPitch)
        recalculateProjectionForCurrentView()
    }

    func setCameraSensitivityMultiplier(_ multiplier: Float) {
        guard multiplier.isFinite else { return }

        cameraSensitivityMultiplier = min(max(multiplier, minimumCameraSensitivity), maximumCameraSensitivity)
    }

    func resetCamera() {
        cameraPosition = MetalRenderer.defaultCameraPosition
        yaw = MetalRenderer.defaultYaw
        pitch = MetalRenderer.defaultPitch
        roll = 0
        zoom = 1.0
        recalculateProjectionForCurrentView()
        rebuildBodyInstanceBuffer(from: currentBodies)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        calculateProjectionMatrix(drawableSize: size)
    }

    func draw(in view: MTKView) {
        updateKeyboardCameraControls(from: view)
        advanceDynamicBufferIndex()

        if let latestBodies = viewModel?.bodies {
            updateBodies(latestBodies)
        }
        if let viewModel {
            updateAsteroidInstances(from: viewModel.asteroidField, currentTime: viewModel.currentTime)
        } else {
            asteroidVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
        }

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        drawBodyInstances(encoder: encoder)
        drawPaths(encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func advanceDynamicBufferIndex() {
        dynamicBufferIndex = (dynamicBufferIndex + 1) % Self.dynamicBufferCount
    }

    private func createSphereMesh(
        latitudeSegments: Int,
        longitudeSegments: Int,
        vertexBufferLabel: String,
        indexBufferLabel: String
    ) -> (vertexBuffer: MTLBuffer, indexBuffer: MTLBuffer, indexCount: Int) {
        let latitudeSegments = max(latitudeSegments, 3)
        let longitudeSegments = max(longitudeSegments, 3)
        let verticesPerRow = longitudeSegments + 1

        var vertices: [SphereVertex] = []
        vertices.reserveCapacity((latitudeSegments + 1) * verticesPerRow)

        for latitude in 0...latitudeSegments {
            let v = Float(latitude) / Float(latitudeSegments)
            let theta = v * Float.pi
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for longitude in 0...longitudeSegments {
                let u = Float(longitude) / Float(longitudeSegments)
                let phi = u * Float.pi * 2

                let position = SIMD3<Float>(
                    sinTheta * cos(phi),
                    sinTheta * sin(phi),
                    cosTheta
                )

                vertices.append(SphereVertex(position: position, normal: position))
            }
        }

        var indices: [UInt16] = []
        indices.reserveCapacity(latitudeSegments * longitudeSegments * 6)

        for latitude in 0..<latitudeSegments {
            for longitude in 0..<longitudeSegments {
                let current = latitude * verticesPerRow + longitude
                let next = current + verticesPerRow

                indices.append(UInt16(current))
                indices.append(UInt16(next))
                indices.append(UInt16(current + 1))

                indices.append(UInt16(current + 1))
                indices.append(UInt16(next))
                indices.append(UInt16(next + 1))
            }
        }

        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SphereVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            fatalError("Could not create sphere vertex buffer.")
        }
        vertexBuffer.label = vertexBufferLabel

        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        ) else {
            fatalError("Could not create sphere index buffer.")
        }
        indexBuffer.label = indexBufferLabel

        return (vertexBuffer, indexBuffer, indices.count)
    }

    private func createIrregularAsteroidMesh(
        latitudeSegments: Int,
        longitudeSegments: Int,
        seed: UInt64
    ) -> MeshResource {
        let latitudeSegments = max(latitudeSegments, 3)
        let longitudeSegments = max(longitudeSegments, 3)
        let verticesPerRow = longitudeSegments + 1
        let stretch = SIMD3<Float>(
            0.78 + Self.deterministicUnitFloat(seed: seed, a: 1, b: 0) * 0.58,
            0.78 + Self.deterministicUnitFloat(seed: seed, a: 2, b: 0) * 0.58,
            0.70 + Self.deterministicUnitFloat(seed: seed, a: 3, b: 0) * 0.46
        )

        var vertices: [SphereVertex] = []
        vertices.reserveCapacity((latitudeSegments + 1) * verticesPerRow)

        for latitude in 0...latitudeSegments {
            let v = Float(latitude) / Float(latitudeSegments)
            let theta = v * Float.pi
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for longitude in 0...longitudeSegments {
                let u = Float(longitude) / Float(longitudeSegments)
                let phi = u * Float.pi * 2
                let normal = simd_normalize(
                    SIMD3<Float>(
                        sinTheta * cos(phi),
                        sinTheta * sin(phi),
                        cosTheta
                    )
                )
                let coarseNoise = Self.deterministicUnitFloat(seed: seed, a: latitude, b: longitude)
                let ridgeNoise = Self.deterministicUnitFloat(seed: seed, a: latitude * 7 + 11, b: longitude * 5 + 23)
                let radialScale = 0.65 + coarseNoise * 0.55 + ridgeNoise * 0.15
                let position = normal * radialScale * stretch

                vertices.append(SphereVertex(position: position, normal: simd_normalize(position)))
            }
        }

        var indices: [UInt16] = []
        indices.reserveCapacity(latitudeSegments * longitudeSegments * 6)

        for latitude in 0..<latitudeSegments {
            for longitude in 0..<longitudeSegments {
                let current = latitude * verticesPerRow + longitude
                let next = current + verticesPerRow

                indices.append(UInt16(current))
                indices.append(UInt16(next))
                indices.append(UInt16(current + 1))

                indices.append(UInt16(current + 1))
                indices.append(UInt16(next))
                indices.append(UInt16(next + 1))
            }
        }

        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SphereVertex>.stride * vertices.count,
            options: .storageModeShared
        ) else {
            fatalError("Could not create asteroid vertex buffer.")
        }
        vertexBuffer.label = "Irregular Asteroid Vertex Buffer"

        guard let indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        ) else {
            fatalError("Could not create asteroid index buffer.")
        }
        indexBuffer.label = "Irregular Asteroid Index Buffer"

        return MeshResource(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, indexCount: indices.count)
    }

    private static func deterministicUnitFloat(seed: UInt64, a: Int, b: Int) -> Float {
        var value = seed
        value ^= UInt64(bitPattern: Int64(a)) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(bitPattern: Int64(b)) &* 0xBF58_476D_1CE4_E5B9
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Float(value & 0x00FF_FFFF) / Float(0x00FF_FFFF)
    }

    private func rebuildBodyInstanceBuffer(from bodies: [CelestialBody]) {
        if let star = bodies.first(where: \.isStar) {
            lightPosition = toRenderPosition(star.position)
        }

        majorBodyInstanceCount = bodies.reduce(0) { $0 + ($1.isAsteroid ? 0 : 1) }

        Self.ensureBodyInstanceBuffer(
            device: device,
            buffers: &majorBodyInstanceBuffers,
            capacities: &majorBodyInstanceCapacities,
            bufferIndex: dynamicBufferIndex,
            requiredCount: majorBodyInstanceCount,
            label: "Major Body Instance Buffer"
        )

        let majorBodyPointer = majorBodyInstanceBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: BodyInstance.self,
            capacity: majorBodyInstanceCapacities[dynamicBufferIndex]
        )

        var majorBodyIndex = 0

        for body in bodies where !body.isAsteroid {
            let instance = BodyInstance(
                positionRadius: SIMD4<Float>(toRenderPosition(body), visualRadius(for: body)),
                color: body.color,
                material: SIMD4<Float>(body.isStar ? 1 : 0, 0, 0, 0)
            )

            majorBodyPointer?[majorBodyIndex] = instance
            majorBodyIndex += 1
        }
    }

    private func rebuildPathBuffer(from bodies: [CelestialBody]) {
        let requiredVertexCount = bodies.reduce(0) { count, body in
            guard !body.isAsteroid else { return count }
            return count + max(0, body.cumulativePosition.count - 1) * 2
        }

        pathVertexCount = requiredVertexCount

        guard requiredVertexCount > 0 else {
            return
        }

        Self.ensurePathVertexBuffer(
            device: device,
            buffers: &pathVertexBuffers,
            capacities: &pathVertexCapacities,
            bufferIndex: dynamicBufferIndex,
            requiredCount: requiredVertexCount
        )

        guard let pathPointer = pathVertexBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: PathVertex.self,
            capacity: pathVertexCapacities[dynamicBufferIndex]
        ) else {
            return
        }

        var vertexIndex = 0

        for body in bodies where !body.isAsteroid {
            guard body.cumulativePosition.count > 1 else { continue }
            let pathColor = SIMD4<Float>(body.color.x, body.color.y, body.color.z, 0.42)

            for index in 1..<body.cumulativePosition.count {
                let previous = body.cumulativePosition[index - 1]
                let current = body.cumulativePosition[index]
                pathPointer[vertexIndex] = PathVertex(position: SIMD4<Float>(toRenderPosition(previous), 1), color: pathColor)
                vertexIndex += 1
                pathPointer[vertexIndex] = PathVertex(position: SIMD4<Float>(toRenderPosition(current), 1), color: pathColor)
                vertexIndex += 1
            }
        }
    }

    private func rebuildStaticOrbitBufferIfNeeded(from bodies: [CelestialBody]) {
        let signature = bodies.map(\.id)
        guard signature != staticOrbitSignature else { return }

        staticOrbitSignature = signature

        guard let sun = bodies.first(where: \.isStar) else {
            staticOrbitVertexCount = 0
            return
        }

        let sunPosition = toRenderPosition(sun.initialPosition)
        var vertices: [PathVertex] = []

        for body in bodies where !body.isStar && !body.isAsteroid && !body.isMoon {
            let bodyPosition = toRenderPosition(body.initialPosition)
            let radius = simd_length(bodyPosition - sunPosition)
            guard radius > 0 else { continue }

            let color = SIMD4<Float>(body.color.x, body.color.y, body.color.z, 0.22)

            for segment in 0..<orbitRingSegmentCount {
                let startAngle = Float(segment) / Float(orbitRingSegmentCount) * Float.pi * 2
                let endAngle = Float(segment + 1) / Float(orbitRingSegmentCount) * Float.pi * 2
                let start = sunPosition + SIMD3<Float>(
                    cos(startAngle) * radius,
                    sin(startAngle) * radius,
                    0
                )
                let end = sunPosition + SIMD3<Float>(
                    cos(endAngle) * radius,
                    sin(endAngle) * radius,
                    0
                )

                vertices.append(PathVertex(position: SIMD4<Float>(start, 1), color: color))
                vertices.append(PathVertex(position: SIMD4<Float>(end, 1), color: color))
            }
        }

        staticOrbitVertexCount = vertices.count

        guard !vertices.isEmpty else { return }

        ensureStaticOrbitVertexBuffer(requiredCount: vertices.count)

        guard let pointer = staticOrbitVertexBuffer?.contents().bindMemory(
            to: PathVertex.self,
            capacity: staticOrbitVertexCapacity
        ) else {
            staticOrbitVertexCount = 0
            return
        }

        for index in vertices.indices {
            pointer[index] = vertices[index]
        }
    }

    private func updateAsteroidInstances(from field: AsteroidField, currentTime: Double) {
        asteroidVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)

        guard !field.asteroids.isEmpty else { return }

        for asteroid in field.asteroids {
            let variant = clampedAsteroidVariant(asteroid.meshVariant)
            asteroidVariantInstanceCounts[variant] += 1
        }

        for variant in 0..<Self.asteroidVariantCount where asteroidVariantInstanceCounts[variant] > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &asteroidVariantInstanceBuffers[variant],
                capacities: &asteroidVariantInstanceCapacities[variant],
                bufferIndex: dynamicBufferIndex,
                requiredCount: asteroidVariantInstanceCounts[variant],
                label: "Asteroid Variant \(variant) Instance Buffer"
            )
        }

        var pointers = Array<UnsafeMutablePointer<BodyInstance>?>(repeating: nil, count: Self.asteroidVariantCount)
        for variant in 0..<Self.asteroidVariantCount where asteroidVariantInstanceCounts[variant] > 0 {
            pointers[variant] = asteroidVariantInstanceBuffers[variant][dynamicBufferIndex]?.contents().bindMemory(
                to: BodyInstance.self,
                capacity: asteroidVariantInstanceCapacities[variant][dynamicBufferIndex]
            )
        }

        var writeIndices = Array(repeating: 0, count: Self.asteroidVariantCount)
        let radiusScale = bodySizeMultiplier / pow(max(zoom, 1.0), zoomRadiusFalloff)

        for asteroid in field.asteroids {
            let variant = clampedAsteroidVariant(asteroid.meshVariant)
            let index = writeIndices[variant]
            writeIndices[variant] += 1

            pointers[variant]?[index] = BodyInstance(
                positionRadius: SIMD4<Float>(
                    asteroidPosition(for: asteroid, currentTime: currentTime),
                    asteroid.sizeAU * radiusScale
                ),
                color: asteroid.color,
                material: SIMD4<Float>(0, 0, 0, 0)
            )
        }
    }

    private func asteroidPosition(for asteroid: AsteroidVisualInstance, currentTime: Double) -> SIMD3<Float> {
        let angle = Double(asteroid.initialAngle) + Double(asteroid.angularSpeed) * currentTime
        let eccentricity = Double(asteroid.eccentricity)
        let radius = Double(asteroid.orbitRadiusAU) * (1 - eccentricity * cos(angle))
        let inclination = Double(asteroid.inclination)
        let x = cos(angle) * radius
        let flatY = sin(angle) * radius
        let y = flatY * cos(inclination)
        let inclinedZ = flatY * sin(inclination)
        let verticalWave = sin(angle + Double(asteroid.initialRotation)) * Double(asteroid.verticalOffsetAU)

        return SIMD3<Float>(Float(x), Float(y), Float(inclinedZ + verticalWave))
    }

    private func clampedAsteroidVariant(_ variant: Int) -> Int {
        min(max(variant, 0), Self.asteroidVariantCount - 1)
    }

    private static func ensureBodyInstanceBuffer(
        device: MTLDevice,
        buffers: inout [MTLBuffer?],
        capacities: inout [Int],
        bufferIndex: Int,
        requiredCount: Int,
        label: String
    ) {
        guard requiredCount > 0 else { return }
        guard buffers[bufferIndex] == nil || capacities[bufferIndex] < requiredCount else { return }

        capacities[bufferIndex] = max(requiredCount, max(1, capacities[bufferIndex] * 2))
        buffers[bufferIndex] = device.makeBuffer(
            length: MemoryLayout<BodyInstance>.stride * capacities[bufferIndex],
            options: .storageModeShared
        )
        buffers[bufferIndex]?.label = "\(label) \(bufferIndex)"
    }

    private static func ensurePathVertexBuffer(
        device: MTLDevice,
        buffers: inout [MTLBuffer?],
        capacities: inout [Int],
        bufferIndex: Int,
        requiredCount: Int
    ) {
        guard requiredCount > 0 else { return }
        guard buffers[bufferIndex] == nil || capacities[bufferIndex] < requiredCount else { return }

        capacities[bufferIndex] = max(requiredCount, max(1, capacities[bufferIndex] * 2))
        buffers[bufferIndex] = device.makeBuffer(
            length: MemoryLayout<PathVertex>.stride * capacities[bufferIndex],
            options: .storageModeShared
        )
        buffers[bufferIndex]?.label = "Path Vertex Buffer \(bufferIndex)"
    }

    private func ensureStaticOrbitVertexBuffer(requiredCount: Int) {
        guard requiredCount > 0 else { return }
        guard staticOrbitVertexBuffer == nil || staticOrbitVertexCapacity < requiredCount else { return }

        staticOrbitVertexCapacity = max(requiredCount, max(1, staticOrbitVertexCapacity * 2))
        staticOrbitVertexBuffer = device.makeBuffer(
            length: MemoryLayout<PathVertex>.stride * staticOrbitVertexCapacity,
            options: .storageModeShared
        )
        staticOrbitVertexBuffer?.label = "Static Orbit Ring Vertex Buffer"
    }

    private func drawBodyInstances(encoder: MTLRenderCommandEncoder) {
        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(bodyPipelineState)
        encoder.setDepthStencilState(bodyDepthStencilState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        drawInstancedBodies(
            encoder: encoder,
            vertexBuffer: highDetailSphereVertexBuffer,
            indexBuffer: highDetailSphereIndexBuffer,
            indexCount: highDetailSphereIndexCount,
            instanceBuffer: majorBodyInstanceBuffers[dynamicBufferIndex],
            instanceCount: majorBodyInstanceCount
        )

        for variant in 0..<min(asteroidMeshVariants.count, Self.asteroidVariantCount) {
            let mesh = asteroidMeshVariants[variant]
            drawInstancedBodies(
                encoder: encoder,
                vertexBuffer: mesh.vertexBuffer,
                indexBuffer: mesh.indexBuffer,
                indexCount: mesh.indexCount,
                instanceBuffer: asteroidVariantInstanceBuffers[variant][dynamicBufferIndex],
                instanceCount: asteroidVariantInstanceCounts[variant]
            )
        }
    }

    private func drawInstancedBodies(
        encoder: MTLRenderCommandEncoder,
        vertexBuffer: MTLBuffer?,
        indexBuffer: MTLBuffer?,
        indexCount: Int,
        instanceBuffer: MTLBuffer?,
        instanceCount: Int
    ) {
        guard let vertexBuffer,
              let indexBuffer,
              let instanceBuffer,
              indexCount > 0,
              instanceCount > 0 else {
            return
        }

        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }

    private func drawPaths(encoder: MTLRenderCommandEncoder) {
        let hasStaticOrbits = staticOrbitVertexBuffer != nil && staticOrbitVertexCount > 0
        let hasDynamicTrails = pathVertexBuffers[dynamicBufferIndex] != nil && pathVertexCount > 0
        guard hasStaticOrbits || hasDynamicTrails else { return }

        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(pathPipelineState)
        encoder.setDepthStencilState(pathDepthStencilState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        if let staticOrbitVertexBuffer, staticOrbitVertexCount > 0 {
            encoder.setVertexBuffer(staticOrbitVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: staticOrbitVertexCount)
        }

        if let pathVertexBuffer = pathVertexBuffers[dynamicBufferIndex], pathVertexCount > 0 {
            encoder.setVertexBuffer(pathVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: pathVertexCount)
        }
    }

    private func makeUniforms() -> Uniforms {
        Uniforms(
            viewProjectionMatrix: worldViewProjectionMatrix,
            lightPosition: SIMD4<Float>(lightPosition, 1),
            cameraPosition: SIMD4<Float>(cameraPosition, 1)
        )
    }

    private func toRenderPosition(_ body: CelestialBody) -> SIMD3<Float> {
        toRenderPosition(body.position)
    }

    private func toRenderPosition(_ position: SIMD3<Double>) -> SIMD3<Float> {
        let scale = SolarSystemConstants.astronomicalUnit
        return SIMD3<Float>(
            Float(position.x / scale),
            Float(position.y / scale),
            Float(position.z / scale)
        )
    }

    func setBodySizeMultiplier(_ multiplier: Float) {
        bodySizeMultiplier = min(max(multiplier, 0.25), 20.0)
        rebuildBodyInstanceBuffer(from: currentBodies)
    }

    private func visualRadius(for body: CelestialBody) -> Float {
        let baseRadius: Float

        if body.isStar {
            baseRadius = sunVisualRadiusAU
        } else if body.isAsteroid {
            baseRadius = asteroidVisualRadiusAU
        } else if body.isMoon {
            let scaled = Float(body.visualRadius / 700_000_000.0) * moonRadiusScale
            baseRadius = max(moonVisualRadiusAU, scaled)
        } else {
            let scaled = Float(body.visualRadius / 700_000_000.0) * planetRadiusScale
            baseRadius = max(minimumPlanetVisualRadiusAU, scaled)
        }

        return (baseRadius * scaleModeMultiplier * bodySizeMultiplier) / pow(max(zoom, 1.0), zoomRadiusFalloff)
    }

    private var scaleModeMultiplier: Float {
        switch scaleMode {
        case .compact:
            compactScaleMultiplier
        case .balanced:
            1.0
        case .realisticDistances:
            realisticScaleMultiplier
        }
    }

    private func recalculateProjectionForCurrentView() {
        guard let view = mtkView else { return }
        calculateProjectionMatrix(drawableSize: view.drawableSize)
    }

    private func updateKeyboardCameraControls(from view: MTKView) {
        let now = Date()
        let deltaTime = min(max(Float(now.timeIntervalSince(lastFrameTime)), 0), maximumMovementDeltaTime)
        lastFrameTime = now

        guard let interactiveView = view as? InteractiveMetalView else { return }

        let movementInput = interactiveView.keyboardMovementInput
        let lookInput = interactiveView.keyboardLookInput
        let rollInput = interactiveView.keyboardRollInput
        let verticalInput = interactiveView.keyboardVerticalInput

        let hasMovement = simd_length_squared(movementInput) > 0 || verticalInput != 0
        let hasLook = simd_length_squared(lookInput) > 0
        let hasRoll = rollInput != 0

        guard hasMovement || hasLook || hasRoll else { return }

        if hasLook {
            let lookSpeed = keyboardLookSpeed * cameraSensitivityMultiplier
            yaw += lookInput.x * lookSpeed * deltaTime
            pitch = min(max(pitch + lookInput.y * lookSpeed * deltaTime, minimumPitch), maximumPitch)
        }

        if hasRoll {
            roll = wrappedAngle(roll + rollInput * keyboardRollSpeed * cameraSensitivityMultiplier * deltaTime)
        }

        if hasMovement {
            let basis = cameraBasis()
            let movementDirection = simd_normalize(
                basis.right * movementInput.x
                    + basis.forward * movementInput.y
                    + basis.up * verticalInput
            )
            let speed = movementSpeed * cameraSensitivityMultiplier / max(zoom, 1)

            cameraPosition += movementDirection * speed * deltaTime
        }

        calculateProjectionMatrix(drawableSize: view.drawableSize)
    }

    private func calculateProjectionMatrix(drawableSize: CGSize) {
        let width = max(Float(drawableSize.width), 1)
        let height = max(Float(drawableSize.height), 1)
        let aspect = width / height

        let basis = cameraBasis()

        let viewMatrix = lookAt(
            eye: cameraPosition,
            center: cameraPosition + basis.forward,
            up: basis.up
        )
        let projectionMatrix = perspective(
            fieldOfViewY: effectiveFieldOfView,
            aspect: aspect,
            near: 0.01,
            far: 5_000
        )

        worldViewProjectionMatrix = projectionMatrix * viewMatrix
    }

    private var effectiveFieldOfView: Float {
        let unclampedFieldOfView = fieldOfViewRadians / max(zoom, minimumZoomScale)
        return min(max(unclampedFieldOfView, minimumFieldOfViewRadians), maximumFieldOfViewRadians)
    }

    private func cameraForward() -> SIMD3<Float> {
        let clampedPitch = min(max(pitch, minimumPitch), maximumPitch)

        return simd_normalize(
            SIMD3<Float>(
                cos(clampedPitch) * sin(yaw),
                cos(clampedPitch) * cos(yaw),
                sin(clampedPitch)
            )
        )
    }

    private func cameraBasis() -> (forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>) {
        let forward = cameraForward()
        let up = cameraUp(forward: forward)
        let right = simd_normalize(simd_cross(forward, up))

        return (forward, right, up)
    }

    private func cameraUp(forward: SIMD3<Float>) -> SIMD3<Float> {
        let worldUp = SIMD3<Float>(0, 0, 1)
        guard abs(simd_dot(forward, worldUp)) < 0.999 else {
            return rotate(SIMD3<Float>(0, 1, 0), around: forward, angle: -roll)
        }

        let baseRight = simd_normalize(simd_cross(forward, worldUp))
        let baseUp = simd_normalize(simd_cross(baseRight, forward))

        return rotate(baseUp, around: forward, angle: -roll)
    }

    private func rotate(_ vector: SIMD3<Float>, around axis: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let normalizedAxis = simd_normalize(axis)
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        return vector * cosAngle
            + simd_cross(normalizedAxis, vector) * sinAngle
            + normalizedAxis * simd_dot(normalizedAxis, vector) * (1 - cosAngle)
    }

    private func wrappedAngle(_ angle: Float) -> Float {
        let period = Float.pi * 2
        var result = angle.truncatingRemainder(dividingBy: period)

        if result > Float.pi {
            result -= period
        } else if result < -Float.pi {
            result += period
        }

        return result
    }

    private func perspective(
        fieldOfViewY: Float,
        aspect: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let yScale = 1 / tan(fieldOfViewY * 0.5)
        let xScale = yScale / aspect
        let zScale = far / (near - far)
        let wzScale = near * far / (near - far)

        return simd_float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        ))
    }

    private func lookAt(
        eye: SIMD3<Float>,
        center: SIMD3<Float>,
        up: SIMD3<Float>
    ) -> simd_float4x4 {
        let zAxis = simd_normalize(eye - center)
        let xAxis = simd_normalize(simd_cross(up, zAxis))
        let yAxis = simd_cross(zAxis, xAxis)

        return simd_float4x4(columns: (
            SIMD4<Float>(xAxis.x, yAxis.x, zAxis.x, 0),
            SIMD4<Float>(xAxis.y, yAxis.y, zAxis.y, 0),
            SIMD4<Float>(xAxis.z, yAxis.z, zAxis.z, 0),
            SIMD4<Float>(-simd_dot(xAxis, eye), -simd_dot(yAxis, eye), -simd_dot(zAxis, eye), 1)
        ))
    }
}

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

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bodyPipelineState: MTLRenderPipelineState
    private let pathPipelineState: MTLRenderPipelineState
    private let bodyDepthStencilState: MTLDepthStencilState
    private let pathDepthStencilState: MTLDepthStencilState

    private weak var mtkView: MTKView?
    private weak var viewModel: SimulationViewModel?

    private var bodyVertexBuffer: MTLBuffer?
    private var sphereIndexBuffer: MTLBuffer?
    private var sphereIndexCount = 0

    private var bodyInstanceBuffer: MTLBuffer?
    private var bodyInstanceCount = 0

    private var pathVertexBuffer: MTLBuffer?
    private var pathVertexCount = 0

    private var currentBodies: [CelestialBody] = []
    private var worldViewProjectionMatrix = matrix_identity_float4x4
    private var lightPosition = SIMD3<Float>(0, 0, 0)

    private var cameraTarget = SIMD3<Float>(0, 0, 0)
    private var cameraPosition = SIMD3<Float>(0, -72, 34)
    private var yaw: Float = -0.65
    private var pitch: Float = 0.48
    private var zoom: Float = 1.0
    private var lastFrameTime = Date()

    private let baseCameraDistance: Float = 72.0
    private let fieldOfViewRadians: Float = Float.pi / 4
    private let orbitSensitivity: Float = 0.006
    private let movementSpeedScale: Float = 0.35
    private let maximumMovementDeltaTime: Float = 1.0 / 15.0
    private let minimumPitch: Float = -1.2
    private let maximumPitch: Float = 1.2

    private var bodySizeMultiplier: Float = 1.0

    private let starRenderRadius: Float = 0.55
    private let planetMinimumRenderRadius: Float = 0.09
    private let planetRenderScale: Float = 0.82
    private let moonRenderRadius: Float = 0.055
    private let asteroidRenderRadius: Float = 0.018
    private let zoomRadiusFalloff: Float = 0.12

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
        createSphereMesh(latitudeSegments: 24, longitudeSegments: 48)
        calculateProjectionMatrix(drawableSize: mtkView.drawableSize)
        updateBodies(viewModel.bodies)
    }

    func updateBodies(_ bodies: [CelestialBody]) {
        currentBodies = bodies
        rebuildBodyInstanceBuffer(from: bodies)
        rebuildPathBuffer(from: bodies)
    }

    func setZoom(_ newZoom: Float) {
        zoom = min(max(newZoom, 0.35), 120.0)
        recalculateProjectionForCurrentView()
        rebuildBodyInstanceBuffer(from: currentBodies)
    }

    func zoomBy(_ factor: Float) {
        setZoom(zoom * factor)
    }

    func panBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        orbitBy(screenDeltaX: dx, screenDeltaY: dy)
    }

    func orbitBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        yaw -= dx * orbitSensitivity
        pitch = min(max(pitch + dy * orbitSensitivity, minimumPitch), maximumPitch)
        recalculateProjectionForCurrentView()
    }

    func resetCamera() {
        cameraTarget = SIMD3<Float>(0, 0, 0)
        yaw = -0.65
        pitch = 0.48
        zoom = 1.0
        recalculateProjectionForCurrentView()
        rebuildBodyInstanceBuffer(from: currentBodies)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        calculateProjectionMatrix(drawableSize: size)
    }

    func draw(in view: MTKView) {
        updateCameraMovement(from: view)

        if let latestBodies = viewModel?.bodies {
            updateBodies(latestBodies)
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

    private func createSphereMesh(latitudeSegments: Int, longitudeSegments: Int) {
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

        sphereIndexCount = indices.count

        bodyVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SphereVertex>.stride * vertices.count,
            options: .storageModeShared
        )
        bodyVertexBuffer?.label = "Sphere Vertex Buffer"

        sphereIndexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        )
        sphereIndexBuffer?.label = "Sphere Index Buffer"
    }

    private func rebuildBodyInstanceBuffer(from bodies: [CelestialBody]) {
        if let star = bodies.first(where: \.isStar) {
            lightPosition = toRenderPosition(star.position)
        }

        let instances = bodies.map { body in
            BodyInstance(
                positionRadius: SIMD4<Float>(toRenderPosition(body), visualRadius(for: body)),
                color: body.color,
                material: SIMD4<Float>(body.isStar ? 1 : 0, 0, 0, 0)
            )
        }

        bodyInstanceCount = instances.count

        guard !instances.isEmpty else {
            bodyInstanceBuffer = nil
            return
        }

        bodyInstanceBuffer = device.makeBuffer(
            bytes: instances,
            length: MemoryLayout<BodyInstance>.stride * instances.count,
            options: .storageModeShared
        )
        bodyInstanceBuffer?.label = "Body Instance Buffer"
    }

    private func rebuildPathBuffer(from bodies: [CelestialBody]) {
        var vertices: [PathVertex] = []
        vertices.reserveCapacity(bodies.reduce(0) { $0 + max(0, $1.cumulativePosition.count - 1) * 2 })

        for body in bodies where !body.isAsteroid {
            guard body.cumulativePosition.count > 1 else { continue }
            let pathColor = SIMD4<Float>(body.color.x, body.color.y, body.color.z, 0.42)

            for index in 1..<body.cumulativePosition.count {
                let previous = body.cumulativePosition[index - 1]
                let current = body.cumulativePosition[index]
                vertices.append(PathVertex(position: SIMD4<Float>(toRenderPosition(previous), 1), color: pathColor))
                vertices.append(PathVertex(position: SIMD4<Float>(toRenderPosition(current), 1), color: pathColor))
            }
        }

        pathVertexCount = vertices.count

        guard !vertices.isEmpty else {
            pathVertexBuffer = nil
            return
        }

        pathVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<PathVertex>.stride * vertices.count,
            options: .storageModeShared
        )
        pathVertexBuffer?.label = "Path Vertex Buffer"
    }

    private func drawBodyInstances(encoder: MTLRenderCommandEncoder) {
        guard let bodyVertexBuffer,
              let bodyInstanceBuffer,
              let sphereIndexBuffer,
              bodyInstanceCount > 0,
              sphereIndexCount > 0 else {
            return
        }

        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(bodyPipelineState)
        encoder.setDepthStencilState(bodyDepthStencilState)
        encoder.setVertexBuffer(bodyVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(bodyInstanceBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: sphereIndexCount,
            indexType: .uint16,
            indexBuffer: sphereIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: bodyInstanceCount
        )
    }

    private func drawPaths(encoder: MTLRenderCommandEncoder) {
        guard let pathVertexBuffer, pathVertexCount > 0 else { return }

        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(pathPipelineState)
        encoder.setDepthStencilState(pathDepthStencilState)
        encoder.setVertexBuffer(pathVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: pathVertexCount)
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
            baseRadius = starRenderRadius
        } else if body.isAsteroid {
            baseRadius = asteroidRenderRadius
        } else if body.isMoon {
            baseRadius = moonRenderRadius
        } else {
            let scaled = Float(body.visualRadius / 700_000_000.0) * planetRenderScale
            baseRadius = max(planetMinimumRenderRadius, scaled)
        }

        return (baseRadius * bodySizeMultiplier) / pow(max(zoom, 1.0), zoomRadiusFalloff)
    }

    private func recalculateProjectionForCurrentView() {
        guard let view = mtkView else { return }
        calculateProjectionMatrix(drawableSize: view.drawableSize)
    }

    private func updateCameraMovement(from view: MTKView) {
        let now = Date()
        let deltaTime = min(max(Float(now.timeIntervalSince(lastFrameTime)), 0), maximumMovementDeltaTime)
        lastFrameTime = now

        guard let interactiveView = view as? InteractiveMetalView else { return }

        let input = interactiveView.keyboardMovementInput
        guard simd_length_squared(input) > 0 else { return }

        let viewDirection = simd_normalize(cameraTarget - cameraPosition)
        let right = simd_normalize(simd_cross(viewDirection, SIMD3<Float>(0, 0, 1)))
        let movementDirection = simd_normalize(right * input.x + viewDirection * input.y)
        let cameraDistance = baseCameraDistance / zoom
        let speed = max(0.08, cameraDistance * movementSpeedScale)

        cameraTarget += movementDirection * speed * deltaTime
        calculateProjectionMatrix(drawableSize: view.drawableSize)
    }

    private func calculateProjectionMatrix(drawableSize: CGSize) {
        let width = max(Float(drawableSize.width), 1)
        let height = max(Float(drawableSize.height), 1)
        let aspect = width / height
        let distance = baseCameraDistance / zoom
        let clampedPitch = min(max(pitch, minimumPitch), maximumPitch)

        cameraPosition = cameraTarget + SIMD3<Float>(
            cos(clampedPitch) * sin(yaw) * distance,
            -cos(clampedPitch) * cos(yaw) * distance,
            sin(clampedPitch) * distance
        )

        let viewMatrix = lookAt(
            eye: cameraPosition,
            center: cameraTarget,
            up: SIMD3<Float>(0, 0, 1)
        )
        let projectionMatrix = perspective(
            fieldOfViewY: fieldOfViewRadians,
            aspect: aspect,
            near: max(0.01, distance * 0.001),
            far: 5_000
        )

        worldViewProjectionMatrix = projectionMatrix * viewMatrix
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

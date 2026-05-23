import Foundation
import MetalKit
import simd

private struct Vertex2D {
    var position: SIMD2<Float>
}

private struct BodyInstance {
    var positionRadius: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct PathVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct Uniforms {
    var viewProjectionMatrix: simd_float4x4
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bodyPipelineState: MTLRenderPipelineState
    private let pathPipelineState: MTLRenderPipelineState

    private weak var mtkView: MTKView?
    private weak var viewModel: SimulationViewModel?

    private var bodyVertexBuffer: MTLBuffer?
    private var circleIndexBuffer: MTLBuffer?
    private var circleIndexCount = 0

    private var bodyInstanceBuffer: MTLBuffer?
    private var bodyInstanceCount = 0

    private var pathVertexBuffer: MTLBuffer?
    private var pathVertexCount = 0

    private var currentBodies: [CelestialBody] = []
    private var worldProjectionMatrix = matrix_identity_float4x4

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
        bodyPipelineDescriptor.label = "Body Pipeline"
        bodyPipelineDescriptor.vertexFunction = bodyVertexFunction
        bodyPipelineDescriptor.fragmentFunction = bodyFragmentFunction
        bodyPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        bodyPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        bodyPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        bodyPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        bodyPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        bodyPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        bodyPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        bodyPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let pathPipelineDescriptor = MTLRenderPipelineDescriptor()
        pathPipelineDescriptor.label = "Path Pipeline"
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

        do {
            self.bodyPipelineState = try device.makeRenderPipelineState(descriptor: bodyPipelineDescriptor)
            self.pathPipelineState = try device.makeRenderPipelineState(descriptor: pathPipelineDescriptor)
        } catch {
            fatalError("Could not create Metal render pipeline states: \(error)")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.mtkView = mtkView
        self.viewModel = viewModel

        super.init()

        print("Using Metal device: \(device.name)")
        createCircleMesh(segmentCount: 48)
        calculateProjectionMatrix(drawableSize: mtkView.drawableSize)
        updateBodies(viewModel.bodies)
    }

    func updateBodies(_ bodies: [CelestialBody]) {
        currentBodies = bodies
        rebuildBodyInstanceBuffer(from: bodies)
        rebuildPathBuffer(from: bodies)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        calculateProjectionMatrix(drawableSize: size)
    }

    func draw(in view: MTKView) {
        if let latestBodies = viewModel?.bodies {
            updateBodies(latestBodies)
        }

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        drawPaths(encoder: encoder)
        drawBodyInstances(encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func createCircleMesh(segmentCount: Int) {
        var vertices: [Vertex2D] = [Vertex2D(position: SIMD2<Float>(0, 0))]

        for index in 0...segmentCount {
            let angle = Float(index) / Float(segmentCount) * Float.pi * 2
            vertices.append(Vertex2D(position: SIMD2<Float>(cos(angle), sin(angle))))
        }

        var indices: [UInt16] = []
        for index in 1...segmentCount {
            indices.append(0)
            indices.append(UInt16(index))
            indices.append(UInt16(index + 1))
        }

        circleIndexCount = indices.count

        bodyVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex2D>.stride * vertices.count,
            options: .storageModeShared
        )
        bodyVertexBuffer?.label = "Circle Vertex Buffer"

        circleIndexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        )
        circleIndexBuffer?.label = "Circle Index Buffer"
    }

    private func rebuildBodyInstanceBuffer(from bodies: [CelestialBody]) {
        let instances = bodies.map { body in
            BodyInstance(
                positionRadius: SIMD4<Float>(toRenderPosition(body), visualRadius(for: body)),
                color: body.color
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
              let circleIndexBuffer,
              bodyInstanceCount > 0,
              circleIndexCount > 0 else {
            return
        }

        var uniforms = Uniforms(viewProjectionMatrix: worldProjectionMatrix)

        encoder.setRenderPipelineState(bodyPipelineState)
        encoder.setVertexBuffer(bodyVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(bodyInstanceBuffer, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: circleIndexCount,
            indexType: .uint16,
            indexBuffer: circleIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: bodyInstanceCount
        )
    }

    private func drawPaths(encoder: MTLRenderCommandEncoder) {
        guard let pathVertexBuffer, pathVertexCount > 0 else { return }

        var uniforms = Uniforms(viewProjectionMatrix: worldProjectionMatrix)

        encoder.setRenderPipelineState(pathPipelineState)
        encoder.setVertexBuffer(pathVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: pathVertexCount)
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

    private func visualRadius(for body: CelestialBody) -> Float {
        if body.isStar { return 0.22 }
        if body.isAsteroid { return 0.008 }
        if body.isMoon { return 0.018 }

        let scaled = Float(body.visualRadius / 700_000_000.0) * 0.32
        return max(0.028, scaled)
    }

    private func calculateProjectionMatrix(drawableSize: CGSize) {
        let width = max(Float(drawableSize.width), 1)
        let height = max(Float(drawableSize.height), 1)
        let aspect = width / height
        let halfExtent: Float = 35.0

        worldProjectionMatrix = orthographic(
            left: -halfExtent * aspect,
            right: halfExtent * aspect,
            bottom: -halfExtent,
            top: halfExtent,
            near: -10,
            far: 10
        )
    }

    private func orthographic(
        left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let rightMinusLeft = right - left
        let topMinusBottom = top - bottom
        let farMinusNear = far - near

        return simd_float4x4(columns: (
            SIMD4<Float>(2 / rightMinusLeft, 0, 0, 0),
            SIMD4<Float>(0, 2 / topMinusBottom, 0, 0),
            SIMD4<Float>(0, 0, -2 / farMinusNear, 0),
            SIMD4<Float>(-(right + left) / rightMinusLeft, -(top + bottom) / topMinusBottom, -(far + near) / farMinusNear, 1)
        ))
    }
}

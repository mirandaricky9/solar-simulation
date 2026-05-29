import Foundation
import MetalKit
import simd

private struct SphereVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
}

private struct BodyInstance {
    var positionRadius: SIMD4<Float>
    var color: SIMD4<Float>
    var material: SIMD4<Float>
    var spinTilt: SIMD4<Float>

    init(
        positionRadius: SIMD4<Float>,
        color: SIMD4<Float>,
        material: SIMD4<Float>,
        spinTilt: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
    ) {
        self.positionRadius = positionRadius
        self.color = color
        self.material = material
        self.spinTilt = spinTilt
    }
}

private struct PathVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct CometBillboardInstance {
    var positionRadius: SIMD4<Float>
    var color: SIMD4<Float>
}

private struct PickableObject {
    let id: UUID
    let name: String
    let kind: CelestialObjectKind
    let worldPositionAU: SIMD3<Float>
    let renderRadiusAU: Float
    let priority: Int
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
    private let cometBillboardPipelineState: MTLRenderPipelineState
    private let bodyDepthStencilState: MTLDepthStencilState
    private let pathDepthStencilState: MTLDepthStencilState
    private let textureLoader: MTKTextureLoader
    private let textureSamplerState: MTLSamplerState

    private weak var mtkView: MTKView?
    private weak var viewModel: SimulationViewModel?

    private var highDetailSphereVertexBuffer: MTLBuffer?
    private var highDetailSphereIndexBuffer: MTLBuffer?
    private var highDetailSphereIndexCount = 0

    private var asteroidMeshVariants: [MeshResource] = []

    private var majorBodyInstanceBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var majorBodyInstanceCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var majorBodyInstanceTextureNames: [String] = []
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

    private var kuiperVariantInstanceBuffers = Array(
        repeating: Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var kuiperVariantInstanceCapacities = Array(
        repeating: Array(repeating: 0, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var kuiperVariantInstanceCounts = Array(repeating: 0, count: MetalRenderer.asteroidVariantCount)

    private var oortVariantInstanceBuffers = Array(
        repeating: Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var oortVariantInstanceCapacities = Array(
        repeating: Array(repeating: 0, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var oortVariantInstanceCounts = Array(repeating: 0, count: MetalRenderer.asteroidVariantCount)

    private var minorDwarfPlanetInstanceBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var minorDwarfPlanetInstanceCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var minorDwarfPlanetInstanceTextureNames: [String] = []
    private var minorDwarfPlanetInstanceCount = 0

    private var minorAsteroidVariantInstanceBuffers = Array(
        repeating: Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var minorAsteroidVariantInstanceCapacities = Array(
        repeating: Array(repeating: 0, count: MetalRenderer.dynamicBufferCount),
        count: MetalRenderer.asteroidVariantCount
    )
    private var minorAsteroidVariantInstanceCounts = Array(repeating: 0, count: MetalRenderer.asteroidVariantCount)

    private var pathVertexBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var pathVertexCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var pathVertexCount = 0

    private var cometNucleusInstanceBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var cometNucleusInstanceCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var cometNucleusInstanceCount = 0

    private var cometComaInstanceBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var cometComaInstanceCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var cometComaInstanceCount = 0

    private var cometTailVertexBuffers = Array<MTLBuffer?>(repeating: nil, count: MetalRenderer.dynamicBufferCount)
    private var cometTailVertexCapacities = Array(repeating: 0, count: MetalRenderer.dynamicBufferCount)
    private var cometTailVertexCount = 0

    private var cometOrbitVertexBuffer: MTLBuffer?
    private var cometOrbitVertexCount = 0

    private var dwarfPlanetOrbitVertexBuffer: MTLBuffer?
    private var dwarfPlanetOrbitVertexCount = 0

    private var notableAsteroidOrbitVertexBuffer: MTLBuffer?
    private var notableAsteroidOrbitVertexCount = 0

    private var staticOrbitVertexBuffer: MTLBuffer?
    private var staticOrbitVertexCapacity = 0
    private var staticOrbitVertexCount = 0
    private var staticOrbitSignature = ""
    private var planetOrbitPaths: [OrbitPathDefinition] = []

    private var dynamicBufferIndex = 0

    private var currentBodies: [CelestialBody] = []
    private var pickableObjects: [PickableObject] = []
    private var worldViewProjectionMatrix = matrix_identity_float4x4
    private var lightPosition = SIMD3<Float>(0, 0, 0)
    private var texturesByBodyName: [String: MTLTexture] = [:]
    private var fallbackWhiteTexture: MTLTexture?

    private var cameraPosition = MetalRenderer.defaultCameraPosition
    private var cameraFocusPoint = SIMD3<Float>(0, 0, 0)
    private var cameraFocusDistance = simd_length(MetalRenderer.defaultCameraPosition)
    private var cameraLockTargetName: String?
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
    var onObjectSelected: ((String) -> Void)?
    var onEmptySelection: (() -> Void)?
    private let scaleMode: ScaleMode = .balanced

    private let sunVisualRadiusAU: Float = 0.08
    private let minimumPlanetVisualRadiusAU: Float = 0.012
    private let moonVisualRadiusAU: Float = 0.006
    private let asteroidVisualRadiusAU: Float = 0.0025
    private let moonParentSeparationPaddingAU: Float = 0.006
    private let minimumMoonOrbitDisplayRadiusAU: Float = 0.015
    private let maximumMoonOrbitDisplayRadiusAU: Float = 0.20
    private let planetRadiusScale: Float = 0.08
    private let moonRadiusScale: Float = 0.06
    private let compactScaleMultiplier: Float = 1.35
    private let realisticScaleMultiplier: Float = 0.45
    private let trueScaleRadiusMultiplier: Float = 1.0
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
              let pathFragmentFunction = library.makeFunction(name: "pathFragmentShader"),
              let cometBillboardVertexFunction = library.makeFunction(name: "cometBillboardVertexShader"),
              let cometBillboardFragmentFunction = library.makeFunction(name: "cometBillboardFragmentShader") else {
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

        let cometBillboardPipelineDescriptor = MTLRenderPipelineDescriptor()
        cometBillboardPipelineDescriptor.label = "Comet Billboard Pipeline"
        cometBillboardPipelineDescriptor.vertexFunction = cometBillboardVertexFunction
        cometBillboardPipelineDescriptor.fragmentFunction = cometBillboardFragmentFunction
        cometBillboardPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        cometBillboardPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        cometBillboardPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        cometBillboardPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        cometBillboardPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        cometBillboardPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        cometBillboardPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        cometBillboardPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        cometBillboardPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        do {
            self.bodyPipelineState = try device.makeRenderPipelineState(descriptor: bodyPipelineDescriptor)
            self.pathPipelineState = try device.makeRenderPipelineState(descriptor: pathPipelineDescriptor)
            self.cometBillboardPipelineState = try device.makeRenderPipelineState(descriptor: cometBillboardPipelineDescriptor)
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

        let textureSamplerDescriptor = MTLSamplerDescriptor()
        textureSamplerDescriptor.minFilter = .linear
        textureSamplerDescriptor.magFilter = .linear
        textureSamplerDescriptor.mipFilter = .linear
        textureSamplerDescriptor.sAddressMode = .repeat
        textureSamplerDescriptor.tAddressMode = .clampToEdge

        guard let textureSamplerState = device.makeSamplerState(descriptor: textureSamplerDescriptor) else {
            fatalError("Could not create texture sampler state.")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.bodyDepthStencilState = bodyDepthStencilState
        self.pathDepthStencilState = pathDepthStencilState
        self.textureLoader = MTKTextureLoader(device: device)
        self.textureSamplerState = textureSamplerState
        self.mtkView = mtkView
        self.viewModel = viewModel

        super.init()

        print("Using Metal device: \(device.name)")
        createFallbackWhiteTexture()
        loadPlanetTextures()

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
        do {
            planetOrbitPaths = try OrbitPathStore.shared.loadPlanetOrbitPaths()
        } catch {
            print("Orbit path load warning: \(error.localizedDescription)")
        }
        rebuildCometOrbitBuffer(definitions: viewModel.cometField.definitions)
        rebuildMinorBodyOrbitBuffers(from: viewModel.minorBodyField)

        calculateProjectionMatrix(drawableSize: mtkView.drawableSize)
        updateBodies(viewModel.bodies)
    }

    func updateBodies(_ bodies: [CelestialBody]) {
        currentBodies = bodies
        rebuildBodyInstanceBuffer(from: bodies)
        rebuildStaticOrbitBufferIfNeeded(from: bodies)

        if viewModel?.showLiveTrails == false {
            pathVertexCount = 0
        } else {
            rebuildPathBuffer(from: bodies)
        }
    }

    func selectObject(at point: CGPoint, in view: MTKView) {
        guard !pickableObjects.isEmpty else {
            onEmptySelection?()
            return
        }

        let drawableWidth = max(Float(view.drawableSize.width), 1)
        let drawableHeight = max(Float(view.drawableSize.height), 1)
        let boundsWidth = max(Float(view.bounds.width), 1)
        let boundsHeight = max(Float(view.bounds.height), 1)
        let clickPosition = SIMD2<Float>(
            Float(point.x) * drawableWidth / boundsWidth,
            (boundsHeight - Float(point.y)) * drawableHeight / boundsHeight
        )

        var bestHit: (object: PickableObject, normalizedDistance: Float)?

        for object in pickableObjects {
            guard let projected = projectToScreen(object, drawableWidth: drawableWidth, drawableHeight: drawableHeight) else {
                continue
            }

            let distance = simd_length(projected.position - clickPosition)
            let pickRadius = max(minimumPickRadius(for: object.kind), min(maximumPickRadius(for: object.kind), projected.radius + 8))
            guard distance <= pickRadius else { continue }

            let normalizedDistance = distance / pickRadius

            if let currentBest = bestHit {
                let isClearlyCloser = normalizedDistance < currentBest.normalizedDistance - 0.15
                let isSimilarHitWithHigherPriority = abs(normalizedDistance - currentBest.normalizedDistance) <= 0.15 &&
                    object.priority > currentBest.object.priority

                if isClearlyCloser || isSimilarHitWithHigherPriority {
                    bestHit = (object, normalizedDistance)
                }
            } else {
                bestHit = (object, normalizedDistance)
            }
        }

        if let bestHit {
            onObjectSelected?(bestHit.object.name)
        } else {
            onEmptySelection?()
        }
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

    func dollyCamera(_ amount: Float) {
        guard amount.isFinite else { return }

        let scaledAmount = amount * cameraSensitivityMultiplier / max(zoom, 1)
        cameraPosition += cameraForward() * scaledAmount
        cameraFocusDistance = max(simd_length(cameraPosition - cameraFocusPoint), 0.1)
        recalculateProjectionForCurrentView()
    }

    func centerCamera(on objectName: String) {
        guard let target = renderPositionForObject(named: objectName) else { return }

        setCameraTargetPreservingView(target)
    }

    func setCameraLockTarget(_ name: String?) {
        cameraLockTargetName = name
    }

    func applyCameraPreset(_ preset: CameraPreset) {
        cameraFocusDistance = max(simd_length(cameraPosition - cameraFocusPoint), 0.1)
        let currentTarget = cameraFocusPoint

        switch preset {
        case .topDown2D:
            yaw = 0
            pitch = -Float.pi / 2
            roll = 0
        case .angled45:
            yaw = 0
            pitch = -Float.pi / 4
            roll = 0
        case .flat0:
            yaw = 0
            pitch = 0
            roll = 0
        }

        cameraPosition = currentTarget - cameraForward() * max(cameraFocusDistance, 0.1)
        recalculateProjectionForCurrentView()
    }

    func panBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        lookBy(screenDeltaX: dx, screenDeltaY: dy)
    }

    func lookBy(screenDeltaX dx: Float, screenDeltaY dy: Float) {
        let sensitivity = lookSensitivity * cameraSensitivityMultiplier
        yaw += dx * sensitivity
        pitch = min(max(pitch + dy * sensitivity, minimumPitch), maximumPitch)
        cameraFocusPoint = cameraPosition + cameraForward() * max(cameraFocusDistance, 0.1)
        recalculateProjectionForCurrentView()
    }

    func setCameraSensitivityMultiplier(_ multiplier: Float) {
        guard multiplier.isFinite else { return }

        cameraSensitivityMultiplier = min(max(multiplier, minimumCameraSensitivity), maximumCameraSensitivity)
    }

    func resetCamera() {
        cameraPosition = MetalRenderer.defaultCameraPosition
        cameraFocusPoint = SIMD3<Float>(0, 0, 0)
        cameraFocusDistance = simd_length(MetalRenderer.defaultCameraPosition)
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
            let cometInstances = viewModel.showComets ? viewModel.cometVisualInstancesForRendering() : []
            let dwarfPlanetInstances = viewModel.showDwarfPlanets
                ? viewModel.dwarfPlanetVisualInstancesForRendering()
                : []
            let notableAsteroidInstances = viewModel.showNotableAsteroids
                ? viewModel.notableAsteroidVisualInstancesForRendering()
                : []
            updateAsteroidInstances(from: viewModel.asteroidField, currentTime: viewModel.currentTime)
            if viewModel.showKuiperBelt {
                updateKuiperBeltInstances(from: viewModel.kuiperBeltField, currentTime: viewModel.currentTime)
            } else {
                kuiperVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            }
            if viewModel.showOortCloud {
                updateOortCloudInstances(from: viewModel.oortCloudField)
            } else {
                oortVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            }
            updateMinorBodyInstances(dwarfPlanets: dwarfPlanetInstances, notableAsteroids: notableAsteroidInstances)
            updateCometInstances(from: cometInstances)
            rebuildPickableObjects(
                from: currentBodies,
                viewModel: viewModel,
                cometInstances: cometInstances,
                minorBodyInstances: dwarfPlanetInstances + notableAsteroidInstances
            )
            updateCameraLockTargetIfNeeded()
        } else {
            asteroidVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            kuiperVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            oortVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            minorDwarfPlanetInstanceCount = 0
            minorAsteroidVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
            updateCometInstances(from: [])
            pickableObjects = []
        }

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        drawBodyInstances(encoder: encoder)
        drawCometComas(encoder: encoder)
        drawPaths(encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func advanceDynamicBufferIndex() {
        dynamicBufferIndex = (dynamicBufferIndex + 1) % Self.dynamicBufferCount
    }

    private func createFallbackWhiteTexture() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("Texture load warning: could not create fallback white texture.")
            return
        }

        var whitePixel: UInt32 = 0xFFFF_FFFF
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &whitePixel,
            bytesPerRow: MemoryLayout<UInt32>.stride
        )
        fallbackWhiteTexture = texture
    }

    private func loadPlanetTextures() {
        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: true,
            .generateMipmaps: true
        ]

        for (bodyName, textureName) in PlanetTextureCatalog.textureNameByBodyName {
            guard let url = planetTextureURL(named: textureName) else {
                print("Texture load warning: missing texture resource for \(bodyName) named \(textureName).")
                continue
            }

            do {
                texturesByBodyName[bodyName] = try textureLoader.newTexture(URL: url, options: options)
            } catch {
                print("Texture load warning: could not load \(textureName) for \(bodyName): \(error.localizedDescription)")
            }
        }
    }

    private func planetTextureURL(named name: String) -> URL? {
        for fileExtension in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Textures/Planets") ??
                Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Textures/Planets") ??
                Bundle.main.url(forResource: name, withExtension: fileExtension) {
                return url
            }
        }

        return nil
    }

    private func texture(forBodyName name: String) -> MTLTexture? {
        texturesByBodyName[name] ?? fallbackWhiteTexture
    }

    private func hasTexture(forBodyName name: String) -> Bool {
        texturesByBodyName[name] != nil
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

                vertices.append(SphereVertex(position: position, normal: position, uv: SIMD2<Float>(u, v)))
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

                vertices.append(SphereVertex(position: position, normal: simd_normalize(position), uv: SIMD2<Float>(u, v)))
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

        majorBodyInstanceCount = bodies.reduce(0) { $0 + (isBodyVisible($1) ? 1 : 0) }
        majorBodyInstanceTextureNames.removeAll(keepingCapacity: true)
        majorBodyInstanceTextureNames.reserveCapacity(majorBodyInstanceCount)

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

        let bodiesByName = Dictionary(uniqueKeysWithValues: bodies.map { ($0.name, $0) })

        for body in bodies where isBodyVisible(body) {
            let instance = BodyInstance(
                positionRadius: SIMD4<Float>(visualRenderPosition(for: body, bodiesByName: bodiesByName), visualRadius(for: body)),
                color: body.color,
                material: SIMD4<Float>(body.isStar ? 1 : 0, hasTexture(forBodyName: body.name) ? 1 : 0, 0, 0),
                spinTilt: spinTilt(for: body)
            )

            majorBodyPointer?[majorBodyIndex] = instance
            majorBodyInstanceTextureNames.append(body.name)
            majorBodyIndex += 1
        }
    }

    private func rebuildPathBuffer(from bodies: [CelestialBody]) {
        let requiredVertexCount = bodies.reduce(0) { count, body in
            guard isBodyVisible(body) else { return count }
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
        let bodiesByName = Dictionary(uniqueKeysWithValues: bodies.map { ($0.name, $0) })

        for body in bodies where isBodyVisible(body) {
            guard body.cumulativePosition.count > 1 else { continue }
            let pathColor = SIMD4<Float>(body.color.x, body.color.y, body.color.z, 0.42)

            for index in 1..<body.cumulativePosition.count {
                let previous = body.cumulativePosition[index - 1]
                let current = body.cumulativePosition[index]
                pathPointer[vertexIndex] = PathVertex(
                    position: SIMD4<Float>(visualTrailRenderPosition(for: body, position: previous, bodiesByName: bodiesByName), 1),
                    color: pathColor
                )
                vertexIndex += 1
                pathPointer[vertexIndex] = PathVertex(
                    position: SIMD4<Float>(visualTrailRenderPosition(for: body, position: current, bodiesByName: bodiesByName), 1),
                    color: pathColor
                )
                vertexIndex += 1
            }
        }
    }

    private func rebuildStaticOrbitBufferIfNeeded(from bodies: [CelestialBody]) {
        let bodySignature = bodies.map { $0.id.uuidString }.joined(separator: ",")
        let visibilitySignature = viewModel?.visiblePlanetNames.sorted().joined(separator: ",") ?? ""
        let signature = bodySignature + "|" + visibilitySignature + "|" + String(planetOrbitPaths.count)
        guard signature != staticOrbitSignature else { return }

        staticOrbitSignature = signature

        let colorByName = Dictionary(uniqueKeysWithValues: bodies.map { ($0.name, $0.color) })
        var vertices: [PathVertex] = []

        if !planetOrbitPaths.isEmpty {
            for path in planetOrbitPaths where path.kind == .planet {
                guard viewModel?.isPlanetVisible(path.objectName) != false,
                      path.pointsAU.count > 1 else {
                    continue
                }

                let baseColor = colorByName[path.objectName] ?? SIMD4<Float>(0.7, 0.7, 0.7, 1)
                let color = SIMD4<Float>(baseColor.x, baseColor.y, baseColor.z, 0.24)

                for index in 1..<path.pointsAU.count {
                    vertices.append(PathVertex(position: SIMD4<Float>(path.pointsAU[index - 1], 1), color: color))
                    vertices.append(PathVertex(position: SIMD4<Float>(path.pointsAU[index], 1), color: color))
                }
            }
        } else {
            appendFallbackCircularOrbitVertices(from: bodies, to: &vertices)
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

    private func spinTilt(for body: CelestialBody) -> SIMD4<Float> {
        if let facts = RotationFactCatalog.byName[body.name] {
            return spinTilt(for: facts)
        }

        if body.isMoon, let orbitalPeriodSeconds = body.orbitalPeriodSeconds, orbitalPeriodSeconds > 0 {
            let facts = RotationFacts(
                rotationPeriodHours: orbitalPeriodSeconds / 3_600,
                axialTiltDegrees: nil,
                isRetrograde: false,
                sourceNote: "Synchronous rotation / tidally locked approximation."
            )
            return spinTilt(for: facts)
        }

        return SIMD4<Float>(0, 0, 0, 0)
    }

    private func spinTilt(for objectName: String) -> SIMD4<Float> {
        guard let facts = RotationFactCatalog.byName[objectName] else {
            return SIMD4<Float>(0, 0, 0, 0)
        }

        return spinTilt(for: facts)
    }

    private func spinTilt(for facts: RotationFacts) -> SIMD4<Float> {
        guard let rotationPeriodSeconds = facts.rotationPeriodSeconds,
              rotationPeriodSeconds > 0 else {
            return SIMD4<Float>(0, 0, 0, 0)
        }

        let elapsedTime = viewModel?.currentTime ?? 0
        let direction = facts.isRetrograde ? -1.0 : 1.0
        let angle = Float(direction * 2.0 * Double.pi * elapsedTime / rotationPeriodSeconds)
        let axialTilt = Float((facts.axialTiltDegrees ?? 0) * Double.pi / 180.0)
        return SIMD4<Float>(angle, axialTilt, 0, 1)
    }

    private func appendFallbackCircularOrbitVertices(from bodies: [CelestialBody], to vertices: inout [PathVertex]) {
        guard let sun = bodies.first(where: \.isStar) else { return }

        let sunPosition = toRenderPosition(sun.initialPosition)
        for body in bodies where !body.isStar && !body.isAsteroid && !body.isMoon && body.kind != .dwarfPlanet {
            guard viewModel?.isPlanetVisible(body.name) != false else { continue }

            let bodyPosition = toRenderPosition(body.initialPosition)
            let radius = simd_length(bodyPosition - sunPosition)
            guard radius > 0 else { continue }

            let color = SIMD4<Float>(body.color.x, body.color.y, body.color.z, 0.16)

            for segment in 0..<orbitRingSegmentCount {
                let startAngle = Float(segment) / Float(orbitRingSegmentCount) * Float.pi * 2
                let endAngle = Float(segment + 1) / Float(orbitRingSegmentCount) * Float.pi * 2
                let start = sunPosition + SIMD3<Float>(cos(startAngle) * radius, sin(startAngle) * radius, 0)
                let end = sunPosition + SIMD3<Float>(cos(endAngle) * radius, sin(endAngle) * radius, 0)
                vertices.append(PathVertex(position: SIMD4<Float>(start, 1), color: color))
                vertices.append(PathVertex(position: SIMD4<Float>(end, 1), color: color))
            }
        }
    }

    private func rebuildPickableObjects(
        from bodies: [CelestialBody],
        viewModel: SimulationViewModel,
        cometInstances: [CometVisualInstance],
        minorBodyInstances: [MinorBodyVisualInstance]
    ) {
        var objects: [PickableObject] = []
        objects.reserveCapacity(bodies.count + cometInstances.count + minorBodyInstances.count + 1)

        let bodiesByName = Dictionary(uniqueKeysWithValues: bodies.map { ($0.name, $0) })

        for body in bodies where isBodyVisible(body) {
            objects.append(
                PickableObject(
                    id: body.id,
                    name: body.name,
                    kind: body.kind,
                    worldPositionAU: visualRenderPosition(for: body, bodiesByName: bodiesByName),
                    renderRadiusAU: visualRadius(for: body),
                    priority: pickPriority(for: body.kind)
                )
            )
        }

        for instance in cometInstances {
            objects.append(
                PickableObject(
                    id: instance.definition.id,
                    name: instance.definition.name,
                    kind: .comet,
                    worldPositionAU: instance.positionAU,
                    renderRadiusAU: max(instance.nucleusRadiusAU, instance.comaRadiusAU * 0.25),
                    priority: pickPriority(for: .comet)
                )
            )
        }

        for instance in minorBodyInstances {
            objects.append(
                PickableObject(
                    id: instance.definition.id,
                    name: instance.definition.name,
                    kind: instance.definition.kind,
                    worldPositionAU: instance.positionAU,
                    renderRadiusAU: instance.renderRadiusAU,
                    priority: pickPriority(for: instance.definition.kind)
                )
            )
        }

        if !viewModel.asteroidField.asteroids.isEmpty {
            objects.append(
                PickableObject(
                    id: UUID(uuidString: "D78A4AF8-711E-4B56-9E33-5AFD02909346")!,
                    name: "Asteroid Belt",
                    kind: .asteroidBelt,
                    worldPositionAU: SIMD3<Float>(2.7, 0, 0),
                    renderRadiusAU: 0.25,
                    priority: pickPriority(for: .asteroidBelt)
                )
            )
        }

        if viewModel.showKuiperBelt {
            objects.append(
                PickableObject(
                    id: UUID(uuidString: "AEF10CF5-D9D2-43A2-B1E2-504A94A5D7F1")!,
                    name: "Kuiper Belt",
                    kind: .kuiperBelt,
                    worldPositionAU: SIMD3<Float>(42, 0, 0),
                    renderRadiusAU: 4.0,
                    priority: pickPriority(for: .kuiperBelt)
                )
            )
        }

        if viewModel.showOortCloud {
            objects.append(
                PickableObject(
                    id: UUID(uuidString: "BB08BF9D-B33A-4669-A79E-0E683449B3A1")!,
                    name: "Oort Cloud",
                    kind: .oortCloud,
                    worldPositionAU: SIMD3<Float>(0, 0, 0),
                    renderRadiusAU: 90,
                    priority: pickPriority(for: .oortCloud)
                )
            )
        }

        pickableObjects = objects
    }

    private func renderPositionForObject(named name: String) -> SIMD3<Float>? {
        let bodiesByName = Dictionary(uniqueKeysWithValues: currentBodies.map { ($0.name, $0) })
        if let body = bodiesByName[name], isBodyVisible(body) {
            return visualRenderPosition(for: body, bodiesByName: bodiesByName)
        }

        return pickableObjects.first { $0.name == name }?.worldPositionAU
    }

    private func updateCameraLockTargetIfNeeded() {
        guard let cameraLockTargetName,
              let targetPosition = renderPositionForObject(named: cameraLockTargetName) else {
            return
        }

        setCameraTargetPreservingView(targetPosition)
    }

    private func setCameraTargetPreservingView(_ target: SIMD3<Float>) {
        cameraFocusDistance = max(simd_length(cameraPosition - cameraFocusPoint), 0.1)
        cameraFocusPoint = target
        cameraPosition = target - cameraForward() * cameraFocusDistance
        recalculateProjectionForCurrentView()
    }

    private func isBodyVisible(_ body: CelestialBody) -> Bool {
        guard !body.isAsteroid else { return false }

        if body.kind == .planet, viewModel?.isPlanetVisible(body.name) == false {
            return false
        }

        if body.kind == .dwarfPlanet || body.parentName == "Pluto" {
            return viewModel?.showDwarfPlanets != false
        }

        return true
    }

    private func visualRenderPosition(for body: CelestialBody, bodiesByName: [String: CelestialBody]) -> SIMD3<Float> {
        guard body.isMoon,
              let parentName = body.parentName,
              body.orbitalRadius != nil,
              let parent = bodiesByName[parentName] else {
            return toRenderPosition(body)
        }

        return visualRenderPosition(for: body, position: body.position, parent: parent)
    }

    private func visualTrailRenderPosition(
        for body: CelestialBody,
        position: SIMD3<Double>,
        bodiesByName: [String: CelestialBody]
    ) -> SIMD3<Float> {
        guard body.isMoon,
              let parentName = body.parentName,
              let parent = bodiesByName[parentName] else {
            return toRenderPosition(position)
        }

        return visualRenderPosition(for: body, position: position, parent: parent)
    }

    private func visualRenderPosition(
        for moon: CelestialBody,
        position: SIMD3<Double>,
        parent: CelestialBody
    ) -> SIMD3<Float> {
        if currentScaleMode == .trueScale {
            return toRenderPosition(position)
        }

        let parentRenderPosition = toRenderPosition(parent)
        let actualMoonRenderPosition = toRenderPosition(position)
        let offset = actualMoonRenderPosition - parentRenderPosition
        let actualDistanceAU = simd_length(offset)
        let direction: SIMD3<Float>

        if actualDistanceAU.isFinite, actualDistanceAU > 0.000001 {
            direction = offset / actualDistanceAU
        } else {
            direction = fallbackMoonDirection(for: moon)
        }

        let minimumVisibleDistance = minimumVisibleMoonDistance(parent: parent, moon: moon)
        let visibleDistance = max(actualDistanceAU, minimumVisibleDistance)

        return parentRenderPosition + direction * visibleDistance
    }

    private func fallbackMoonDirection(for moon: CelestialBody) -> SIMD3<Float> {
        let phase = Float(moon.orbitalPhase ?? 0)
        let direction = SIMD3<Float>(cos(phase), sin(phase), 0)

        if direction.x.isFinite, direction.y.isFinite, simd_length_squared(direction) > 0 {
            return simd_normalize(direction)
        }

        return SIMD3<Float>(1, 0, 0)
    }

    private func minimumVisibleMoonDistance(parent: CelestialBody, moon: CelestialBody) -> Float {
        min(
            max(
                visualRadius(for: parent) + visualRadius(for: moon) + moonParentSeparationPaddingAU,
                minimumMoonOrbitDisplayRadiusAU
            ),
            maximumMoonOrbitDisplayRadiusAU
        )
    }

    private func pickPriority(for kind: CelestialObjectKind) -> Int {
        switch kind {
        case .moon:
            return 100
        case .comet:
            return 90
        case .planet, .dwarfPlanet:
            return 80
        case .star:
            return 10
        case .asteroidBelt, .kuiperBelt, .oortCloud:
            return 1
        case .asteroid:
            return 1
        case .unknown:
            return 0
        }
    }

    private func minimumPickRadius(for kind: CelestialObjectKind) -> Float {
        switch kind {
        case .star:
            return 14
        case .moon:
            return 8
        case .comet:
            return 10
        case .planet, .dwarfPlanet:
            return 10
        case .asteroidBelt:
            return 18
        case .kuiperBelt:
            return 16
        case .oortCloud:
            return 14
        case .asteroid:
            return 8
        case .unknown:
            return 10
        }
    }

    private func maximumPickRadius(for kind: CelestialObjectKind) -> Float {
        switch kind {
        case .asteroidBelt, .kuiperBelt:
            return 90
        case .oortCloud:
            return 120
        case .star:
            return 70
        default:
            return 52
        }
    }

    private func projectToScreen(
        _ object: PickableObject,
        drawableWidth: Float,
        drawableHeight: Float
    ) -> (position: SIMD2<Float>, radius: Float)? {
        let position = object.worldPositionAU
        let clip = worldViewProjectionMatrix * SIMD4<Float>(position, 1)
        guard clip.w.isFinite, clip.w > 0.000001 else { return nil }

        let ndc = SIMD3<Float>(clip.x / clip.w, clip.y / clip.w, clip.z / clip.w)
        guard ndc.x.isFinite, ndc.y.isFinite, ndc.z.isFinite else { return nil }
        guard ndc.x >= -1.05, ndc.x <= 1.05, ndc.y >= -1.05, ndc.y <= 1.05 else { return nil }

        let screenPosition = SIMD2<Float>(
            (ndc.x * 0.5 + 0.5) * drawableWidth,
            (1 - (ndc.y * 0.5 + 0.5)) * drawableHeight
        )
        let radius = projectedRadiusPixels(for: object, drawableWidth: drawableWidth, drawableHeight: drawableHeight)

        return (screenPosition, radius)
    }

    private func projectedRadiusPixels(
        for object: PickableObject,
        drawableWidth: Float,
        drawableHeight: Float
    ) -> Float {
        let position = object.worldPositionAU
        let offsetPosition = position + SIMD3<Float>(max(object.renderRadiusAU, 0.001), 0, 0)
        let centerClip = worldViewProjectionMatrix * SIMD4<Float>(position, 1)
        let edgeClip = worldViewProjectionMatrix * SIMD4<Float>(offsetPosition, 1)
        guard centerClip.w > 0.000001, edgeClip.w > 0.000001 else { return 0 }

        let centerNDC = SIMD2<Float>(centerClip.x / centerClip.w, centerClip.y / centerClip.w)
        let edgeNDC = SIMD2<Float>(edgeClip.x / edgeClip.w, edgeClip.y / edgeClip.w)
        guard centerNDC.x.isFinite, centerNDC.y.isFinite, edgeNDC.x.isFinite, edgeNDC.y.isFinite else { return 0 }
        let centerScreen = SIMD2<Float>(
            (centerNDC.x * 0.5 + 0.5) * drawableWidth,
            (1 - (centerNDC.y * 0.5 + 0.5)) * drawableHeight
        )
        let edgeScreen = SIMD2<Float>(
            (edgeNDC.x * 0.5 + 0.5) * drawableWidth,
            (1 - (edgeNDC.y * 0.5 + 0.5)) * drawableHeight
        )

        return simd_length(edgeScreen - centerScreen)
    }

    private func updateMinorBodyInstances(
        dwarfPlanets: [MinorBodyVisualInstance],
        notableAsteroids: [MinorBodyVisualInstance]
    ) {
        minorDwarfPlanetInstanceCount = dwarfPlanets.count
        minorDwarfPlanetInstanceTextureNames.removeAll(keepingCapacity: true)
        minorDwarfPlanetInstanceTextureNames.reserveCapacity(minorDwarfPlanetInstanceCount)
        minorAsteroidVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)

        if minorDwarfPlanetInstanceCount > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &minorDwarfPlanetInstanceBuffers,
                capacities: &minorDwarfPlanetInstanceCapacities,
                bufferIndex: dynamicBufferIndex,
                requiredCount: minorDwarfPlanetInstanceCount,
                label: "Minor Dwarf Planet Instance Buffer"
            )
        }

        for asteroid in notableAsteroids {
            minorAsteroidVariantInstanceCounts[clampedAsteroidVariant(asteroid.meshVariant)] += 1
        }

        for variant in 0..<Self.asteroidVariantCount where minorAsteroidVariantInstanceCounts[variant] > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &minorAsteroidVariantInstanceBuffers[variant],
                capacities: &minorAsteroidVariantInstanceCapacities[variant],
                bufferIndex: dynamicBufferIndex,
                requiredCount: minorAsteroidVariantInstanceCounts[variant],
                label: "Notable Asteroid Variant \(variant) Instance Buffer"
            )
        }

        if let dwarfPointer = minorDwarfPlanetInstanceBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: BodyInstance.self,
            capacity: minorDwarfPlanetInstanceCapacities[dynamicBufferIndex]
        ) {
            for index in dwarfPlanets.indices {
                let instance = dwarfPlanets[index]
                dwarfPointer[index] = BodyInstance(
                    positionRadius: SIMD4<Float>(
                        instance.positionAU,
                        visualRadius(for: instance.definition, enhancedRadiusAU: instance.renderRadiusAU)
                    ),
                    color: instance.color,
                    material: SIMD4<Float>(0, hasTexture(forBodyName: instance.definition.name) ? 1 : 0, 0, 0),
                    spinTilt: spinTilt(for: instance.definition.name)
                )
                minorDwarfPlanetInstanceTextureNames.append(instance.definition.name)
            }
        }

        var pointers = Array<UnsafeMutablePointer<BodyInstance>?>(repeating: nil, count: Self.asteroidVariantCount)
        for variant in 0..<Self.asteroidVariantCount where minorAsteroidVariantInstanceCounts[variant] > 0 {
            pointers[variant] = minorAsteroidVariantInstanceBuffers[variant][dynamicBufferIndex]?.contents().bindMemory(
                to: BodyInstance.self,
                capacity: minorAsteroidVariantInstanceCapacities[variant][dynamicBufferIndex]
            )
        }

        var writeIndices = Array(repeating: 0, count: Self.asteroidVariantCount)
        for asteroid in notableAsteroids {
            let variant = clampedAsteroidVariant(asteroid.meshVariant)
            let index = writeIndices[variant]
            writeIndices[variant] += 1
            pointers[variant]?[index] = BodyInstance(
                positionRadius: SIMD4<Float>(
                    asteroid.positionAU,
                    visualRadius(for: asteroid.definition, enhancedRadiusAU: asteroid.renderRadiusAU)
                ),
                color: asteroid.color,
                material: SIMD4<Float>(0, 0, 0, 0),
                spinTilt: spinTilt(for: asteroid.definition.name)
            )
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

    private func updateKuiperBeltInstances(from field: KuiperBeltVisualField, currentTime: Double) {
        kuiperVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
        guard !field.objects.isEmpty else { return }

        for object in field.objects {
            kuiperVariantInstanceCounts[clampedAsteroidVariant(object.meshVariant)] += 1
        }

        for variant in 0..<Self.asteroidVariantCount where kuiperVariantInstanceCounts[variant] > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &kuiperVariantInstanceBuffers[variant],
                capacities: &kuiperVariantInstanceCapacities[variant],
                bufferIndex: dynamicBufferIndex,
                requiredCount: kuiperVariantInstanceCounts[variant],
                label: "Kuiper Belt Variant \(variant) Instance Buffer"
            )
        }

        var pointers = Array<UnsafeMutablePointer<BodyInstance>?>(repeating: nil, count: Self.asteroidVariantCount)
        for variant in 0..<Self.asteroidVariantCount where kuiperVariantInstanceCounts[variant] > 0 {
            pointers[variant] = kuiperVariantInstanceBuffers[variant][dynamicBufferIndex]?.contents().bindMemory(
                to: BodyInstance.self,
                capacity: kuiperVariantInstanceCapacities[variant][dynamicBufferIndex]
            )
        }

        var writeIndices = Array(repeating: 0, count: Self.asteroidVariantCount)
        let radiusScale = bodySizeMultiplier / pow(max(zoom, 1.0), zoomRadiusFalloff)

        for object in field.objects {
            let variant = clampedAsteroidVariant(object.meshVariant)
            let index = writeIndices[variant]
            writeIndices[variant] += 1
            pointers[variant]?[index] = BodyInstance(
                positionRadius: SIMD4<Float>(kuiperPosition(for: object, currentTime: currentTime), object.sizeAU * radiusScale),
                color: object.color,
                material: SIMD4<Float>(0, 0, 0, 0)
            )
        }
    }

    private func kuiperPosition(for object: KuiperBeltVisualInstance, currentTime: Double) -> SIMD3<Float> {
        let angle = Double(object.initialAngle) + Double(object.angularSpeed) * currentTime
        let radius = Double(object.orbitRadiusAU) * (1 - Double(object.eccentricity) * cos(angle))
        let inclination = Double(object.inclination)
        let x = cos(angle) * radius
        let flatY = sin(angle) * radius
        let y = flatY * cos(inclination)
        let z = flatY * sin(inclination) + Double(object.verticalOffsetAU)
        return SIMD3<Float>(Float(x), Float(y), Float(z))
    }

    private func updateOortCloudInstances(from field: OortCloudVisualField) {
        oortVariantInstanceCounts = Array(repeating: 0, count: Self.asteroidVariantCount)
        guard !field.objects.isEmpty else { return }

        for object in field.objects {
            oortVariantInstanceCounts[clampedAsteroidVariant(object.meshVariant)] += 1
        }

        for variant in 0..<Self.asteroidVariantCount where oortVariantInstanceCounts[variant] > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &oortVariantInstanceBuffers[variant],
                capacities: &oortVariantInstanceCapacities[variant],
                bufferIndex: dynamicBufferIndex,
                requiredCount: oortVariantInstanceCounts[variant],
                label: "Oort Cloud Variant \(variant) Instance Buffer"
            )
        }

        var pointers = Array<UnsafeMutablePointer<BodyInstance>?>(repeating: nil, count: Self.asteroidVariantCount)
        for variant in 0..<Self.asteroidVariantCount where oortVariantInstanceCounts[variant] > 0 {
            pointers[variant] = oortVariantInstanceBuffers[variant][dynamicBufferIndex]?.contents().bindMemory(
                to: BodyInstance.self,
                capacity: oortVariantInstanceCapacities[variant][dynamicBufferIndex]
            )
        }

        var writeIndices = Array(repeating: 0, count: Self.asteroidVariantCount)
        let radiusScale = bodySizeMultiplier / pow(max(zoom, 1.0), zoomRadiusFalloff)
        let compression: Float = currentScaleMode == .trueScale ? 1 : 0.02

        for object in field.objects {
            let variant = clampedAsteroidVariant(object.meshVariant)
            let index = writeIndices[variant]
            writeIndices[variant] += 1
            pointers[variant]?[index] = BodyInstance(
                positionRadius: SIMD4<Float>(object.positionAU * compression, object.sizeAU * radiusScale),
                color: object.color,
                material: SIMD4<Float>(0, 0, 0, 0)
            )
        }
    }

    private func clampedAsteroidVariant(_ variant: Int) -> Int {
        min(max(variant, 0), Self.asteroidVariantCount - 1)
    }

    private func updateCometInstances(from instances: [CometVisualInstance]) {
        cometNucleusInstanceCount = instances.count
        cometComaInstanceCount = instances.count
        cometTailVertexCount = instances.reduce(0) { count, instance in
            count + (instance.tailLengthAU > 0.001 ? 2 : 0)
        }

        if cometNucleusInstanceCount > 0 {
            Self.ensureBodyInstanceBuffer(
                device: device,
                buffers: &cometNucleusInstanceBuffers,
                capacities: &cometNucleusInstanceCapacities,
                bufferIndex: dynamicBufferIndex,
                requiredCount: cometNucleusInstanceCount,
                label: "Comet Nucleus Instance Buffer"
            )
        }

        if cometComaInstanceCount > 0 {
            ensureCometBillboardInstanceBuffer(requiredCount: cometComaInstanceCount)
        }

        if cometTailVertexCount > 0 {
            Self.ensurePathVertexBuffer(
                device: device,
                buffers: &cometTailVertexBuffers,
                capacities: &cometTailVertexCapacities,
                bufferIndex: dynamicBufferIndex,
                requiredCount: cometTailVertexCount
            )
        }

        let radiusScale = bodySizeMultiplier / pow(max(zoom, 1.0), zoomRadiusFalloff)

        if let nucleusPointer = cometNucleusInstanceBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: BodyInstance.self,
            capacity: cometNucleusInstanceCapacities[dynamicBufferIndex]
        ) {
            for index in instances.indices {
                let instance = instances[index]
                nucleusPointer[index] = BodyInstance(
                    positionRadius: SIMD4<Float>(
                        instance.positionAU,
                        visualCometNucleusRadius(for: instance) * radiusScale
                    ),
                    color: SIMD4<Float>(0.55, 0.53, 0.49, 1),
                    material: SIMD4<Float>(0, 0, 0, 0),
                    spinTilt: spinTilt(for: instance.definition.name)
                )
            }
        }

        if let comaPointer = cometComaInstanceBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: CometBillboardInstance.self,
            capacity: cometComaInstanceCapacities[dynamicBufferIndex]
        ) {
            for index in instances.indices {
                let instance = instances[index]
                let activity = cometActivity(for: instance)
                comaPointer[index] = CometBillboardInstance(
                    positionRadius: SIMD4<Float>(instance.positionAU, instance.comaRadiusAU),
                    color: SIMD4<Float>(
                        instance.color.x,
                        instance.color.y,
                        instance.color.z,
                        0.05 + activity * 0.34
                    )
                )
            }
        }

        if let tailPointer = cometTailVertexBuffers[dynamicBufferIndex]?.contents().bindMemory(
            to: PathVertex.self,
            capacity: cometTailVertexCapacities[dynamicBufferIndex]
        ) {
            var vertexIndex = 0

            for instance in instances where instance.tailLengthAU > 0.001 {
                let tailDirection = simd_normalize(instance.positionAU)
                let activity = cometActivity(for: instance)
                let endpoint = instance.positionAU + tailDirection * instance.tailLengthAU
                let startColor = SIMD4<Float>(instance.color.x, instance.color.y, instance.color.z, 0.55 * activity)
                let endColor = SIMD4<Float>(instance.color.x, instance.color.y, instance.color.z, 0.0)

                tailPointer[vertexIndex] = PathVertex(position: SIMD4<Float>(instance.positionAU, 1), color: startColor)
                vertexIndex += 1
                tailPointer[vertexIndex] = PathVertex(position: SIMD4<Float>(endpoint, 1), color: endColor)
                vertexIndex += 1
            }
        }
    }

    private func cometActivity(for instance: CometVisualInstance) -> Float {
        guard instance.definition.tailLengthAU > 0 else { return 0 }

        return min(max(instance.tailLengthAU / instance.definition.tailLengthAU, 0), 1)
    }

    private func ensureCometBillboardInstanceBuffer(requiredCount: Int) {
        guard requiredCount > 0 else { return }
        guard cometComaInstanceBuffers[dynamicBufferIndex] == nil ||
                cometComaInstanceCapacities[dynamicBufferIndex] < requiredCount else {
            return
        }

        cometComaInstanceCapacities[dynamicBufferIndex] = max(
            requiredCount,
            max(1, cometComaInstanceCapacities[dynamicBufferIndex] * 2)
        )
        cometComaInstanceBuffers[dynamicBufferIndex] = device.makeBuffer(
            length: MemoryLayout<CometBillboardInstance>.stride * cometComaInstanceCapacities[dynamicBufferIndex],
            options: .storageModeShared
        )
        cometComaInstanceBuffers[dynamicBufferIndex]?.label = "Comet Coma Instance Buffer \(dynamicBufferIndex)"
    }

    private func rebuildCometOrbitBuffer(definitions: [CometDefinition]) {
        let segmentCount = 1_024
        let maximumRenderedRadiusAU: Float = 80
        var vertices: [PathVertex] = []

        for definition in definitions {
            let color = SIMD4<Float>(definition.color.x, definition.color.y, definition.color.z, 0.14)
            var previousPosition: SIMD3<Float>?

            for segment in 0...segmentCount {
                let meanAnomaly = Double(segment) / Double(segmentCount) * Double.pi * 2
                let position = KeplerOrbitSolver.positionAU(
                    definition: definition,
                    meanAnomaly: meanAnomaly
                )
                let isRenderable = isRenderableCometOrbitPoint(position, maximumRadiusAU: maximumRenderedRadiusAU)

                if let previousPosition, isRenderable {
                    vertices.append(PathVertex(position: SIMD4<Float>(previousPosition, 1), color: color))
                    vertices.append(PathVertex(position: SIMD4<Float>(position, 1), color: color))
                }

                previousPosition = isRenderable ? position : nil
            }
        }

        cometOrbitVertexCount = vertices.count

        guard !vertices.isEmpty else { return }

        cometOrbitVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<PathVertex>.stride * vertices.count,
            options: .storageModeShared
        )
        cometOrbitVertexBuffer?.label = "Comet Orbit Vertex Buffer"
    }

    private func rebuildMinorBodyOrbitBuffers(from field: MinorBodyVisualField) {
        let dwarfVertices = minorBodyOrbitVertices(
            definitions: field.dwarfPlanets,
            maximumRenderedRadiusAU: 120,
            alpha: 0.16
        )
        dwarfPlanetOrbitVertexCount = dwarfVertices.count
        dwarfPlanetOrbitVertexBuffer = makePathBuffer(vertices: dwarfVertices, label: "Dwarf Planet Orbit Vertex Buffer")

        let asteroidVertices = minorBodyOrbitVertices(
            definitions: field.notableAsteroids,
            maximumRenderedRadiusAU: 80,
            alpha: 0.12
        )
        notableAsteroidOrbitVertexCount = asteroidVertices.count
        notableAsteroidOrbitVertexBuffer = makePathBuffer(vertices: asteroidVertices, label: "Notable Asteroid Orbit Vertex Buffer")
    }

    private func minorBodyOrbitVertices(
        definitions: [MinorBodyDefinition],
        maximumRenderedRadiusAU: Float,
        alpha: Float
    ) -> [PathVertex] {
        let segmentCount = 720
        var vertices: [PathVertex] = []

        for definition in definitions {
            let color = SIMD4<Float>(definition.color.x, definition.color.y, definition.color.z, alpha)
            var previousPosition: SIMD3<Float>?

            for segment in 0...segmentCount {
                let meanAnomaly = Double(segment) / Double(segmentCount) * Double.pi * 2
                let position = KeplerOrbitSolver.positionAU(definition: definition, meanAnomaly: meanAnomaly)
                let isRenderable = isRenderableOrbitPoint(position, maximumRadiusAU: maximumRenderedRadiusAU)

                if let previousPosition, isRenderable {
                    vertices.append(PathVertex(position: SIMD4<Float>(previousPosition, 1), color: color))
                    vertices.append(PathVertex(position: SIMD4<Float>(position, 1), color: color))
                }

                previousPosition = isRenderable ? position : nil
            }
        }

        return vertices
    }

    private func makePathBuffer(vertices: [PathVertex], label: String) -> MTLBuffer? {
        guard !vertices.isEmpty else { return nil }

        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<PathVertex>.stride * vertices.count,
            options: .storageModeShared
        )
        buffer?.label = label
        return buffer
    }

    private func isRenderableCometOrbitPoint(_ position: SIMD3<Float>, maximumRadiusAU: Float) -> Bool {
        isRenderableOrbitPoint(position, maximumRadiusAU: maximumRadiusAU)
    }

    private func isRenderableOrbitPoint(_ position: SIMD3<Float>, maximumRadiusAU: Float) -> Bool {
        position.x.isFinite &&
            position.y.isFinite &&
            position.z.isFinite &&
            simd_length(position) <= maximumRadiusAU
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
        encoder.setFragmentSamplerState(textureSamplerState, index: 0)

        drawTexturedMajorBodies(encoder: encoder)
        if let fallbackWhiteTexture {
            encoder.setFragmentTexture(fallbackWhiteTexture, index: 0)
        }

        drawTexturedMinorDwarfPlanets(encoder: encoder)
        if let fallbackWhiteTexture {
            encoder.setFragmentTexture(fallbackWhiteTexture, index: 0)
        }

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
            drawInstancedBodies(
                encoder: encoder,
                vertexBuffer: mesh.vertexBuffer,
                indexBuffer: mesh.indexBuffer,
                indexCount: mesh.indexCount,
                instanceBuffer: minorAsteroidVariantInstanceBuffers[variant][dynamicBufferIndex],
                instanceCount: minorAsteroidVariantInstanceCounts[variant]
            )
            drawInstancedBodies(
                encoder: encoder,
                vertexBuffer: mesh.vertexBuffer,
                indexBuffer: mesh.indexBuffer,
                indexCount: mesh.indexCount,
                instanceBuffer: kuiperVariantInstanceBuffers[variant][dynamicBufferIndex],
                instanceCount: kuiperVariantInstanceCounts[variant]
            )
            drawInstancedBodies(
                encoder: encoder,
                vertexBuffer: mesh.vertexBuffer,
                indexBuffer: mesh.indexBuffer,
                indexCount: mesh.indexCount,
                instanceBuffer: oortVariantInstanceBuffers[variant][dynamicBufferIndex],
                instanceCount: oortVariantInstanceCounts[variant]
            )
        }

        if let cometMesh = asteroidMeshVariants.first {
            drawInstancedBodies(
                encoder: encoder,
                vertexBuffer: cometMesh.vertexBuffer,
                indexBuffer: cometMesh.indexBuffer,
                indexCount: cometMesh.indexCount,
                instanceBuffer: cometNucleusInstanceBuffers[dynamicBufferIndex],
                instanceCount: cometNucleusInstanceCount
            )
        }
    }

    private func drawTexturedMajorBodies(encoder: MTLRenderCommandEncoder) {
        drawTexturedBodies(
            encoder: encoder,
            vertexBuffer: highDetailSphereVertexBuffer,
            indexBuffer: highDetailSphereIndexBuffer,
            indexCount: highDetailSphereIndexCount,
            instanceBuffer: majorBodyInstanceBuffers[dynamicBufferIndex],
            instanceCount: majorBodyInstanceCount,
            textureNames: majorBodyInstanceTextureNames
        )
    }

    private func drawTexturedMinorDwarfPlanets(encoder: MTLRenderCommandEncoder) {
        drawTexturedBodies(
            encoder: encoder,
            vertexBuffer: highDetailSphereVertexBuffer,
            indexBuffer: highDetailSphereIndexBuffer,
            indexCount: highDetailSphereIndexCount,
            instanceBuffer: minorDwarfPlanetInstanceBuffers[dynamicBufferIndex],
            instanceCount: minorDwarfPlanetInstanceCount,
            textureNames: minorDwarfPlanetInstanceTextureNames
        )
    }

    private func drawTexturedBodies(
        encoder: MTLRenderCommandEncoder,
        vertexBuffer: MTLBuffer?,
        indexBuffer: MTLBuffer?,
        indexCount: Int,
        instanceBuffer: MTLBuffer?,
        instanceCount: Int,
        textureNames: [String]
    ) {
        guard let vertexBuffer,
              let indexBuffer,
              let instanceBuffer,
              indexCount > 0,
              instanceCount > 0 else {
            return
        }

        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        for index in 0..<instanceCount {
            let bodyName = index < textureNames.count ? textureNames[index] : ""
            if let texture = texture(forBodyName: bodyName) {
                encoder.setFragmentTexture(texture, index: 0)
            }

            encoder.setVertexBuffer(
                instanceBuffer,
                offset: MemoryLayout<BodyInstance>.stride * index,
                index: 1
            )
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexCount,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0,
                instanceCount: 1
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

    private func drawCometComas(encoder: MTLRenderCommandEncoder) {
        guard let comaBuffer = cometComaInstanceBuffers[dynamicBufferIndex],
              cometComaInstanceCount > 0 else {
            return
        }

        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(cometBillboardPipelineState)
        encoder.setDepthStencilState(pathDepthStencilState)
        encoder.setVertexBuffer(comaBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: cometComaInstanceCount
        )
    }

    private func drawPaths(encoder: MTLRenderCommandEncoder) {
        let shouldDrawComets = viewModel?.showComets == true
        let shouldDrawDwarfPlanets = viewModel?.showDwarfPlanets != false
        let shouldDrawNotableAsteroids = viewModel?.showNotableAsteroids == true
        let shouldDrawPretracedPaths = viewModel?.showPretracedOrbitPaths != false
        let shouldDrawLiveTrails = viewModel?.showLiveTrails != false
        let hasStaticOrbits = shouldDrawPretracedPaths && staticOrbitVertexBuffer != nil && staticOrbitVertexCount > 0
        let hasDwarfPlanetOrbits = shouldDrawPretracedPaths && shouldDrawDwarfPlanets && dwarfPlanetOrbitVertexBuffer != nil && dwarfPlanetOrbitVertexCount > 0
        let hasNotableAsteroidOrbits = shouldDrawPretracedPaths && shouldDrawNotableAsteroids && notableAsteroidOrbitVertexBuffer != nil && notableAsteroidOrbitVertexCount > 0
        let hasCometOrbits = shouldDrawPretracedPaths && shouldDrawComets && cometOrbitVertexBuffer != nil && cometOrbitVertexCount > 0
        let hasCometTails = shouldDrawComets && cometTailVertexBuffers[dynamicBufferIndex] != nil && cometTailVertexCount > 0
        let hasDynamicTrails = shouldDrawLiveTrails && pathVertexBuffers[dynamicBufferIndex] != nil && pathVertexCount > 0
        guard hasStaticOrbits || hasDwarfPlanetOrbits || hasNotableAsteroidOrbits || hasCometOrbits || hasCometTails || hasDynamicTrails else { return }

        var uniforms = makeUniforms()

        encoder.setRenderPipelineState(pathPipelineState)
        encoder.setDepthStencilState(pathDepthStencilState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        if let staticOrbitVertexBuffer, shouldDrawPretracedPaths, staticOrbitVertexCount > 0 {
            encoder.setVertexBuffer(staticOrbitVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: staticOrbitVertexCount)
        }

        if let dwarfPlanetOrbitVertexBuffer, shouldDrawPretracedPaths, shouldDrawDwarfPlanets, dwarfPlanetOrbitVertexCount > 0 {
            encoder.setVertexBuffer(dwarfPlanetOrbitVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: dwarfPlanetOrbitVertexCount)
        }

        if let notableAsteroidOrbitVertexBuffer, shouldDrawPretracedPaths, shouldDrawNotableAsteroids, notableAsteroidOrbitVertexCount > 0 {
            encoder.setVertexBuffer(notableAsteroidOrbitVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: notableAsteroidOrbitVertexCount)
        }

        if let cometOrbitVertexBuffer, shouldDrawPretracedPaths, shouldDrawComets, cometOrbitVertexCount > 0 {
            encoder.setVertexBuffer(cometOrbitVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: cometOrbitVertexCount)
        }

        if let cometTailVertexBuffer = cometTailVertexBuffers[dynamicBufferIndex],
           shouldDrawComets,
           cometTailVertexCount > 0 {
            encoder.setVertexBuffer(cometTailVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: cometTailVertexCount)
        }

        if let pathVertexBuffer = pathVertexBuffers[dynamicBufferIndex], shouldDrawLiveTrails, pathVertexCount > 0 {
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
        if currentScaleMode == .trueScale {
            return Float(body.visualRadius / SolarSystemConstants.astronomicalUnit) * trueScaleRadiusMultiplier * bodySizeMultiplier
        }

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

        return (baseRadius * enhancedScaleModeMultiplier * bodySizeMultiplier) / pow(max(zoom, 1.0), zoomRadiusFalloff)
    }

    private func visualRadius(for definition: MinorBodyDefinition, enhancedRadiusAU: Float) -> Float {
        if currentScaleMode == .trueScale, let radiusMeters = definition.meanRadiusMeters {
            return Float(radiusMeters / SolarSystemConstants.astronomicalUnit) * trueScaleRadiusMultiplier * bodySizeMultiplier
        }

        return (enhancedRadiusAU * bodySizeMultiplier) / pow(max(zoom, 1.0), zoomRadiusFalloff)
    }

    private func visualCometNucleusRadius(for instance: CometVisualInstance) -> Float {
        instance.nucleusRadiusAU
    }

    private var currentScaleMode: SimulationScaleMode {
        viewModel?.scaleMode ?? .enhanced
    }

    private var enhancedScaleModeMultiplier: Float {
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
            let movementDelta = movementDirection * speed * deltaTime

            cameraPosition += movementDelta

            let centerPanDelta = (basis.right * movementInput.x + basis.up * verticalInput) * speed * deltaTime
            if simd_length_squared(centerPanDelta) > 0 {
                cameraFocusPoint += centerPanDelta
            }
            cameraFocusDistance = max(simd_length(cameraPosition - cameraFocusPoint), 0.1)
        }

        if hasLook {
            cameraFocusPoint = cameraPosition + cameraForward() * max(cameraFocusDistance, 0.1)
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
            far: 150_000
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

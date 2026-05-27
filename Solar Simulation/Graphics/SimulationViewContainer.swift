import MetalKit
import SwiftUI

struct SimulationViewContainer: NSViewRepresentable {
    @ObservedObject var viewModel: SimulationViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac.")
        }

        let mtkView = InteractiveMetalView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearDepth = 1.0
        mtkView.clearColor = MTLClearColor(red: 0.005, green: 0.006, blue: 0.012, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        let selectionViewModel = viewModel
        let renderer = MetalRenderer(mtkView: mtkView, viewModel: viewModel)
        renderer.setCameraSensitivityMultiplier(Float(viewModel.cameraSensitivity))
        renderer.onObjectSelected = { [weak selectionViewModel] selectedName in
            Task { @MainActor in
                selectionViewModel?.selectObject(named: selectedName)
            }
        }
        renderer.onEmptySelection = { [weak selectionViewModel] in
            Task { @MainActor in
                selectionViewModel?.clearSelection()
            }
        }
        context.coordinator.renderer = renderer
        mtkView.delegate = renderer

        mtkView.onScroll = { [weak renderer] factor in
            renderer?.zoomBy(factor)
        }

        mtkView.onDrag = { [weak renderer] dx, dy in
            renderer?.panBy(screenDeltaX: dx, screenDeltaY: dy)
        }

        mtkView.onResetCamera = { [weak renderer] in
            renderer?.resetCamera()
        }

        mtkView.onClick = { [weak renderer, weak mtkView] point in
            guard let mtkView else { return }
            renderer?.selectObject(at: point, in: mtkView)
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }

        renderer.updateBodies(viewModel.bodies)
        renderer.setCameraSensitivityMultiplier(Float(viewModel.cameraSensitivity))

        if context.coordinator.lastCameraResetRequestID != viewModel.cameraResetRequestID {
            renderer.resetCamera()
            context.coordinator.lastCameraResetRequestID = viewModel.cameraResetRequestID
        }
    }

    final class Coordinator {
        var renderer: MetalRenderer?
        var lastCameraResetRequestID = 0
    }
}

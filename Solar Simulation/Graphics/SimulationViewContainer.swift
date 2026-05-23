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

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .invalid
        mtkView.clearColor = MTLClearColor(red: 0.005, green: 0.006, blue: 0.012, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        let renderer = MetalRenderer(mtkView: mtkView, viewModel: viewModel)
        context.coordinator.renderer = renderer
        mtkView.delegate = renderer

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderer?.updateBodies(viewModel.bodies)
    }

    final class Coordinator {
        var renderer: MetalRenderer?
    }
}

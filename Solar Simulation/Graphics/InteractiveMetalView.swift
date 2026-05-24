import MetalKit
import simd

final class InteractiveMetalView: MTKView {
    var onScroll: ((Float) -> Void)?
    var onDrag: ((Float, Float) -> Void)?
    var onResetCamera: (() -> Void)?

    private var lastDragLocation: NSPoint?
    private var pressedMovementKeys: Set<UInt16> = []

    var keyboardMovementInput: SIMD2<Float> {
        var input = SIMD2<Float>(0, 0)

        if pressedMovementKeys.contains(KeyCode.a) {
            input.x -= 1
        }

        if pressedMovementKeys.contains(KeyCode.d) {
            input.x += 1
        }

        if pressedMovementKeys.contains(KeyCode.w) {
            input.y += 1
        }

        if pressedMovementKeys.contains(KeyCode.s) {
            input.y -= 1
        }

        let length = simd_length(input)
        return length > 1 ? input / length : input
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = Float(event.scrollingDeltaY)

        if delta > 0 {
            onScroll?(1.1)
        } else if delta < 0 {
            onScroll?(0.9)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastDragLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)

        if let last = lastDragLocation {
            let dx = Float(current.x - last.x)
            let dy = Float(current.y - last.y)
            onDrag?(dx, dy)
        }

        lastDragLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onResetCamera?()
    }

    override func keyDown(with event: NSEvent) {
        if updateMovementKey(event.keyCode, isPressed: true) {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if updateMovementKey(event.keyCode, isPressed: false) {
            return
        }

        super.keyUp(with: event)
    }

    override func resignFirstResponder() -> Bool {
        pressedMovementKeys.removeAll()
        return super.resignFirstResponder()
    }

    @discardableResult
    private func updateMovementKey(_ keyCode: UInt16, isPressed: Bool) -> Bool {
        guard KeyCode.movementKeys.contains(keyCode) else {
            return false
        }

        if isPressed {
            pressedMovementKeys.insert(keyCode)
        } else {
            pressedMovementKeys.remove(keyCode)
        }

        return true
    }
}

private enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13

    static let movementKeys: Set<UInt16> = [w, a, s, d]
}

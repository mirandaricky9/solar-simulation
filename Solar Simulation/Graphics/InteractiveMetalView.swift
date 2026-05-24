import MetalKit
import simd

final class InteractiveMetalView: MTKView {
    var onScroll: ((Float) -> Void)?
    var onDrag: ((Float, Float) -> Void)?
    var onResetCamera: (() -> Void)?

    private var lastDragLocation: NSPoint?
    private var pressedCameraKeys: Set<UInt16> = []

    var keyboardMovementInput: SIMD2<Float> {
        var input = SIMD2<Float>(0, 0)

        if pressedCameraKeys.contains(KeyCode.a) {
            input.x -= 1
        }

        if pressedCameraKeys.contains(KeyCode.d) {
            input.x += 1
        }

        if pressedCameraKeys.contains(KeyCode.w) {
            input.y += 1
        }

        if pressedCameraKeys.contains(KeyCode.s) {
            input.y -= 1
        }

        let length = simd_length(input)
        return length > 1 ? input / length : input
    }

    var keyboardLookInput: SIMD2<Float> {
        var input = SIMD2<Float>(0, 0)

        if pressedCameraKeys.contains(KeyCode.leftArrow) {
            input.x -= 1
        }

        if pressedCameraKeys.contains(KeyCode.rightArrow) {
            input.x += 1
        }

        if pressedCameraKeys.contains(KeyCode.upArrow) {
            input.y += 1
        }

        if pressedCameraKeys.contains(KeyCode.downArrow) {
            input.y -= 1
        }

        let length = simd_length(input)
        return length > 1 ? input / length : input
    }

    var keyboardRollInput: Float {
        var input: Float = 0

        if pressedCameraKeys.contains(KeyCode.q) {
            input += 1
        }

        if pressedCameraKeys.contains(KeyCode.e) {
            input -= 1
        }

        return input
    }

    var keyboardVerticalInput: Float {
        var input: Float = 0

        if pressedCameraKeys.contains(KeyCode.space) {
            input += 1
        }

        if pressedCameraKeys.contains(KeyCode.leftControl) {
            input -= 1
        }

        return input
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
        if updateCameraKey(event.keyCode, isPressed: true) {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if updateCameraKey(event.keyCode, isPressed: false) {
            return
        }

        super.keyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if event.keyCode == KeyCode.leftControl {
            updateCameraKey(event.keyCode, isPressed: event.modifierFlags.contains(.control))
            return
        }

        super.flagsChanged(with: event)
    }

    override func resignFirstResponder() -> Bool {
        pressedCameraKeys.removeAll()
        return super.resignFirstResponder()
    }

    @discardableResult
    private func updateCameraKey(_ keyCode: UInt16, isPressed: Bool) -> Bool {
        guard KeyCode.cameraKeys.contains(keyCode) else {
            return false
        }

        if isPressed {
            pressedCameraKeys.insert(keyCode)
        } else {
            pressedCameraKeys.remove(keyCode)
        }

        return true
    }
}

private enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let q: UInt16 = 12
    static let w: UInt16 = 13
    static let e: UInt16 = 14
    static let space: UInt16 = 49
    static let leftControl: UInt16 = 59

    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126

    static let cameraKeys: Set<UInt16> = [
        w, a, s, d,
        q, e,
        space, leftControl,
        leftArrow, rightArrow, upArrow, downArrow
    ]
}

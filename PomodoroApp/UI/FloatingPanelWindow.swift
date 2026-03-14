import AppKit
import SwiftUI

@MainActor
final class FloatingPanelWindow: NSPanel {
    private var hostingView: NSHostingView<ControlsView>?

    init(timerEngine: TimerEngine, audioEngine: AudioEngine) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 240),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        let hosting = NSHostingView(rootView: ControlsView(timerEngine: timerEngine, audioEngine: audioEngine))
        hosting.setFrameSize(hosting.fittingSize)
        contentView = hosting
        setContentSize(hosting.fittingSize)
        hostingView = hosting
        setFrameAutosaveName("FloatingPanel2")
    }

    // Allow clicks on buttons inside the panel
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Prevent the panel from hiding when it resigns key
    override func resignKey() {
        super.resignKey()
        // Stay visible — don't hide
    }

    // Resize the window when SwiftUI content changes size
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        guard let hosting = hostingView else { return }
        let newSize = hosting.fittingSize
        if abs(frame.size.width - newSize.width) > 1 || abs(frame.size.height - newSize.height) > 1 {
            // Keep top-left pinned by adjusting origin for height change
            let heightDelta = newSize.height - frame.size.height
            var newOrigin = frame.origin
            newOrigin.y -= heightDelta
            setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: true)
        }
    }

    // Click on empty space dismisses the panel
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        if let contentView = contentView, let hitView = contentView.hitTest(location) {
            if hitView === contentView {
                orderOut(nil)
                return
            }
        }
        super.mouseDown(with: event)
    }
}

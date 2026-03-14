import AppKit
import SwiftUI

@MainActor
final class FloatingPanelWindow: NSPanel {
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

        // No title bar — borderless panel

        let hostingView = NSHostingView(rootView: ControlsView(timerEngine: timerEngine, audioEngine: audioEngine))
        hostingView.setFrameSize(hostingView.fittingSize)
        contentView = hostingView
        setContentSize(hostingView.fittingSize)
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

    // Click on empty space dismisses the panel
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        if let contentView = contentView, let hitView = contentView.hitTest(location) {
            // If the hit view is the content view itself (background), dismiss
            if hitView === contentView {
                orderOut(nil)
                return
            }
        }
        super.mouseDown(with: event)
    }
}

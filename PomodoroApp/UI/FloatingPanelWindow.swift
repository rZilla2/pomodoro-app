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

        appearance = NSAppearance(named: .darkAqua)

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
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        contentView = hosting
        setContentSize(hosting.fittingSize)
        hostingView = hosting
        setFrameAutosaveName("FloatingPanel2")
    }

    // Allow clicks on buttons inside the panel
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Prevent the panel from hiding when it resigns key
    override func resignKey() {
        super.resignKey()
        // Stay visible — don't hide
    }

    // Resize the window when SwiftUI content changes size — pin top edge, grow downward
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        guard let hosting = hostingView else { return }
        let newSize = hosting.fittingSize
        if abs(frame.size.width - newSize.width) > 1 || abs(frame.size.height - newSize.height) > 1 {
            // macOS origin is bottom-left; pin the top edge by adjusting y
            let topY = frame.origin.y + frame.size.height
            let newOrigin = NSPoint(x: frame.origin.x, y: topY - newSize.height)
            setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
        }
    }

}

import AppKit
import SwiftUI

@MainActor
final class FloatingPanelWindow: NSPanel {
    init(timerEngine: TimerEngine) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true

        // Hide standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        contentView = NSHostingView(rootView: ControlsView(timerEngine: timerEngine))

        setFrameAutosaveName("FloatingPanel")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

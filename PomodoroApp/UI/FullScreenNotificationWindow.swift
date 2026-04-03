import AppKit
import SwiftUI

@MainActor
final class FullScreenNotificationWindow: NSWindow {

    init?(view: some View) {
        guard let screen = NSScreen.main else { return nil }

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        isMovable = false

        let hosting = NSHostingView(rootView: view)
        hosting.frame = screen.frame
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

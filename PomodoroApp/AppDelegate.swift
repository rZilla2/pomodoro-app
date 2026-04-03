import AppKit
import Combine
import OSLog
import ServiceManagement
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.rzilla.pomodoro", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var audioEngine: AudioEngine?
    var timerEngine: TimerEngine?
    var floatingPanel: FloatingPanelWindow?
    var notificationWindow: FullScreenNotificationWindow?
    private var pillView: StatusBarPillView?
    private var cancellables = Set<AnyCancellable>()
    private var hidePanelObserver: NSObjectProtocol?
    private var workCompleteObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance: quit if another copy is already running
        let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != .current }
        if !dominated.isEmpty {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let audio = AudioEngine()
        audioEngine = audio
        let engine = TimerEngine(audioEngine: audio)
        timerEngine = engine

        // Set up status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.image?.size = NSSize(width: 22, height: 22)
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.title = formatTime(engine.workDuration * 60)
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        // Subscribe to timeRemaining for live countdown
        engine.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Subscribe to timerState for prefix changes
        engine.$timerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)

        // Set up floating panel
        let panel = FloatingPanelWindow(timerEngine: engine, audioEngine: audio)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth = panel.frame.width
            let x = screenFrame.maxX - panelWidth - 12
            let y = screenFrame.maxY - panel.frame.height - 8
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        floatingPanel = panel

        // Listen for hide-panel requests from custom traffic light close button
        hidePanelObserver = NotificationCenter.default.addObserver(
            forName: .hidePanelRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.floatingPanel?.orderOut(nil)
            }
        }

        // Listen for work session completion → show full-screen notification
        workCompleteObserver = NotificationCenter.default.addObserver(
            forName: .workSessionComplete,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showFullScreenNotification()
            }
        }

        // Register for launch at login (only if not already registered)
        if SMAppService.mainApp.status == .notRegistered {
            do {
                try SMAppService.mainApp.register()
            } catch {
                logger.error("Failed to register launch at login: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Status Item Title

    private func updateStatusTitle() {
        guard let engine = timerEngine, let button = statusItem?.button else { return }
        let time = formatTime(engine.timeRemaining)

        // Determine which SF Symbol to show
        let symbolName: String?
        switch engine.timerState {
        case .idle:
            symbolName = nil
        case .running:
            symbolName = engine.currentMode == .break_ ? "cup.and.saucer.fill" : "play.fill"
        case .paused:
            symbolName = "pause.fill"
        case .onBreak:
            symbolName = "cup.and.saucer.fill"
        case .waitingForUser:
            symbolName = "bell.fill"
        }

        let iconName = symbolName ?? "timer"

        if let existing = pillView {
            existing.update(iconName: iconName, time: time)
            let size = existing.fittingSize
            existing.frame = NSRect(origin: .zero, size: size)
            button.frame = NSRect(origin: button.frame.origin, size: size)
            statusItem?.length = size.width
        } else {
            let pv = StatusBarPillView(iconName: iconName, time: time)
            pv.onTap = { [weak self] in self?.statusItemClicked() }
            pv.onRightClick = { [weak self] event in self?.showContextMenu(from: event) }
            let size = pv.fittingSize
            pv.frame = NSRect(origin: .zero, size: size)
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(pv)
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "")
            button.frame = NSRect(origin: button.frame.origin, size: size)
            statusItem?.length = size.width
            pillView = pv
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Status Item Click → Toggle Panel

    @objc private func statusItemClicked() {
        togglePanel()
    }

    // MARK: - Floating Panel

    func showPanel() {
        floatingPanel?.orderFrontRegardless()
    }

    func togglePanel() {
        if let panel = floatingPanel, panel.isVisible {
            floatingPanel?.orderOut(nil)
        } else {
            showPanel()
        }
    }

    // MARK: - Full-Screen Notification

    private func showFullScreenNotification() {
        let view = FullScreenNotificationView(
            onDismiss: { [weak self] in
                self?.dismissNotification()
                self?.timerEngine?.stop()
            },
            onRestart: { [weak self] in
                self?.dismissNotification()
                self?.timerEngine?.start()
            },
            onAddTime: { [weak self] minutes in
                self?.dismissNotification()
                self?.timerEngine?.snooze(minutes: minutes)
            },
            onBreak: { [weak self] minutes in
                self?.dismissNotification()
                self?.timerEngine?.startBreakWithDuration(seconds: minutes * 60)
            }
        )
        guard let window = FullScreenNotificationWindow(view: view) else { return }
        notificationWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissNotification() {
        notificationWindow?.orderOut(nil)
        notificationWindow = nil
    }

    // MARK: - Right-Click Context Menu

    private func showContextMenu(from event: NSEvent) {
        guard let engine = timerEngine else { return }
        let menu = NSMenu()

        let focusItem = NSMenuItem(title: "Focus \(engine.workDuration)", action: #selector(menuStartFocus), keyEquivalent: "")
        focusItem.target = self
        menu.addItem(focusItem)

        let breakItem = NSMenuItem(title: "Break \(engine.breakDuration)", action: #selector(menuBreak), keyEquivalent: "")
        breakItem.target = self
        menu.addItem(breakItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show the menu at the status item
        if let button = statusItem?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func menuStartFocus() { timerEngine?.start() }
    @objc private func menuPause() { timerEngine?.pause() }
    @objc private func menuBreak() { timerEngine?.startBreak() }
    @objc private func menuStop() { timerEngine?.stop() }
    @objc private func menuTogglePanel() { togglePanel() }
    @objc private func menuQuit() { NSApplication.shared.terminate(nil) }
}

// MARK: - Status Bar Pill View

@MainActor
final class StatusBarPillView: NSView {
    var onTap: (() -> Void)?

    private static let rustyRed = NSColor(red: 0.78, green: 0.30, blue: 0.24, alpha: 1.0)
    private static let hPad: CGFloat = 8
    private static let iconTextGap: CGFloat = 5
    private static let cornerRadius: CGFloat = 5

    // Menu bar is 22pt; use full height with 2pt inset top/bottom
    private static let barHeight: CGFloat = 22
    private static let pillHeight: CGFloat = barHeight - 2
    private static let fontSize: CGFloat = 13
    private static let iconPt: CGFloat = 14

    private(set) var iconName: String
    private(set) var time: String

    init(iconName: String, time: String) {
        self.iconName = iconName
        self.time = time
        super.init(frame: .zero)
        setAccessibilityLabel("Pomodoro timer: \(time)")
        setAccessibilityRole(.button)
    }

    func update(iconName: String, time: String) {
        guard self.iconName != iconName || self.time != time else { return }
        self.iconName = iconName
        self.time = time
        setAccessibilityLabel("Pomodoro timer: \(time)")
        let newSize = fittingSize
        frame = NSRect(origin: frame.origin, size: newSize)
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var fittingSize: NSSize {
        let font = NSFont.monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .medium)
        let textSize = (time as NSString).size(withAttributes: [.font: font])
        let width = Self.hPad + Self.iconPt + Self.iconTextGap + textSize.width + Self.hPad
        return NSSize(width: ceil(width), height: Self.barHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Center the pill vertically in the menu bar slot
        let pillY = (bounds.height - Self.pillHeight) / 2
        let pillRect = NSRect(x: 0, y: pillY, width: bounds.width, height: Self.pillHeight)
        let pill = NSBezierPath(roundedRect: pillRect, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        Self.rustyRed.setFill()
        pill.fill()

        let font = NSFont.monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .medium)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (time as NSString).size(withAttributes: textAttrs)

        let contentWidth = Self.iconPt + Self.iconTextGap + textSize.width
        let startX = (bounds.width - contentWidth) / 2

        // Draw SF Symbol icon in white — use actual symbol size for proper centering
        if let symbol = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: Self.iconPt, weight: .medium)
                .applying(.init(paletteColors: [.white]))
            if let tinted = symbol.withSymbolConfiguration(config) {
                let actualSize = tinted.size
                let iconX = startX + (Self.iconPt - actualSize.width) / 2
                let iconY = pillY + (Self.pillHeight - actualSize.height) / 2
                tinted.draw(in: NSRect(x: iconX, y: iconY, width: actualSize.width, height: actualSize.height))
            }
        }

        // Draw time text in white
        let textX = startX + Self.iconPt + Self.iconTextGap
        let textY = pillY + (Self.pillHeight - textSize.height) / 2
        (time as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)
    }

    override func mouseUp(with event: NSEvent) {
        onTap?()
    }

    override func rightMouseUp(with event: NSEvent) {
        onRightClick?(event)
    }

    var onRightClick: ((NSEvent) -> Void)?
}

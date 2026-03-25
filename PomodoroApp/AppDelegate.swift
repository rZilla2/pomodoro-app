import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var audioEngine: AudioEngine?
    var timerEngine: TimerEngine?
    var floatingPanel: FloatingPanelWindow?
    var notificationWindow: FullScreenNotificationWindow?
    private var cancellables = Set<AnyCancellable>()

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
            button.image = NSImage(systemSymbolName: "flame", accessibilityDescription: "Pomodoro")
            button.image?.size = NSSize(width: 14, height: 14)
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
        NotificationCenter.default.addObserver(
            forName: .init("hidePanelRequested"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.floatingPanel?.orderOut(nil)
            }
        }

        // Listen for work session completion → show full-screen notification
        NotificationCenter.default.addObserver(
            forName: .workSessionComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showFullScreenNotification()
            }
        }

        // Register for launch at login (only if not already registered)
        if SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }
    }

    // MARK: - Status Item Title

    private func updateStatusTitle() {
        guard let engine = timerEngine, let button = statusItem?.button else { return }
        let time = formatTime(engine.timeRemaining)

        // Determine which SF Symbol to show between flame and timer
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

        // Pick the icon: flame when idle, state-specific otherwise
        let iconName = symbolName ?? "flame"
        guard let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) else { return }

        let attributed = NSMutableAttributedString()

        // Icon as inline attachment
        let attachment = NSTextAttachment()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        attachment.image = symbolImage.withSymbolConfiguration(config)
        let iconString = NSAttributedString(attachment: attachment)
        attributed.append(iconString)

        // Space + time
        attributed.append(NSAttributedString(string: " \(time)"))

        // Font for the whole string
        let font = button.font ?? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: font, range: range)
        // Nudge baseline so icon aligns vertically with text
        let iconRange = NSRange(location: 0, length: iconString.length)
        attributed.addAttribute(.baselineOffset, value: -1.0, range: iconRange)

        button.image = nil
        button.attributedTitle = attributed
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
                self?.timerEngine?.startBreak()
            },
            onSnooze: { [weak self] in
                self?.dismissNotification()
                self?.timerEngine?.snooze(minutes: 5)
            }
        )
        let window = FullScreenNotificationWindow(view: view)
        notificationWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissNotification() {
        notificationWindow?.orderOut(nil)
        notificationWindow = nil
    }
}

import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timerEngine: TimerEngine?
    var floatingPanel: FloatingPanelWindow?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let engine = TimerEngine()
        timerEngine = engine

        // Set up status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.title = formatTime(engine.workDuration * 60)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Set up popover with MenuBarView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(timerEngine: engine))
        self.popover = popover

        // Subscribe to timeRemaining for live countdown
        engine.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
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
        let panel = FloatingPanelWindow(timerEngine: engine)
        panel.center()
        floatingPanel = panel

        // Register for launch at login (zero-friction)
        registerLaunchAtLogin()
    }

    // MARK: - Status Item Title

    private func updateStatusTitle() {
        guard let engine = timerEngine else { return }
        let time = formatTime(engine.timeRemaining)

        switch engine.timerState {
        case .idle:
            statusItem?.button?.title = time
        case .running:
            if engine.currentMode == .break_ {
                statusItem?.button?.title = "~ \(time)"
            } else {
                statusItem?.button?.title = time
            }
        case .paused:
            statusItem?.button?.title = "|| \(time)"
        case .onBreak:
            statusItem?.button?.title = "~ \(time)"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover's window can receive key events
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Floating Panel

    func showPanel() {
        floatingPanel?.orderFrontRegardless()
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
    }

    func togglePanel() {
        if let panel = floatingPanel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Launch at Login

    private func registerLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register launch at login: \(error)")
        }
    }
}

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
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
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

    // MARK: - Status Item Click → Toggle Panel

    @objc private func statusItemClicked() {
        togglePanel()
    }

    // MARK: - Floating Panel

    func showPanel() {
        floatingPanel?.orderFrontRegardless()
    }

    @objc func hidePanelAction() {
        floatingPanel?.orderOut(nil)
    }

    func togglePanel() {
        if let panel = floatingPanel, panel.isVisible {
            hidePanelAction()
        } else {
            showPanel()
        }
    }

    // MARK: - Launch at Login

    private func registerLaunchAtLogin() {
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register launch at login: \(error)")
        }
    }
}

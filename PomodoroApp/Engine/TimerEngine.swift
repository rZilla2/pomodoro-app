import SwiftUI
import AppKit

@MainActor
final class TimerEngine: ObservableObject {
    enum TimerState: Sendable { case idle, running, paused, onBreak }
    enum Mode: Sendable { case work, break_ }

    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var currentMode: Mode = .work

    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("breakDuration") var breakDuration: Int = 5

    private var startDate: Date?
    private var targetDuration: Int = 0
    private var ticker: Timer?
    private var pausedRemaining: Int = 0

    // MARK: - Public API

    func start() {
        if timerState == .paused {
            resumeFromPause()
            return
        }
        targetDuration = (currentMode == .work ? workDuration : breakDuration) * 60
        beginSession()
    }

    /// Start with a custom duration in seconds (for testing)
    func startWithDuration(seconds: Int) {
        currentMode = .work
        targetDuration = seconds
        beginSession()
    }

    /// Start break with a custom duration in seconds (for testing)
    func startBreakWithDuration(seconds: Int) {
        ticker?.invalidate()
        ticker = nil
        currentMode = .break_
        targetDuration = seconds
        beginSession()
    }

    func pause() {
        guard timerState == .running else { return }
        pausedRemaining = timeRemaining
        ticker?.invalidate()
        ticker = nil
        timerState = .paused
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        startDate = nil
        currentMode = .work
        timeRemaining = workDuration * 60
        timerState = .idle
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    // MARK: - Private

    private func beginSession() {
        startDate = Date()
        timeRemaining = targetDuration
        timerState = .running
        scheduleTicker()
        subscribeToWake()
    }

    private func resumeFromPause() {
        // Adjust startDate so elapsed time calculation accounts for paused time
        targetDuration = pausedRemaining
        startDate = Date()
        timeRemaining = pausedRemaining
        timerState = .running
        scheduleTicker()
    }

    private func scheduleTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func subscribeToWake() {
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let start = startDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        timeRemaining = max(0, targetDuration - elapsed)
        if timeRemaining == 0 {
            handleSessionComplete()
        }
    }

    private func handleSessionComplete() {
        ticker?.invalidate()
        ticker = nil
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)

        if currentMode == .work {
            // Auto-transition to break
            currentMode = .break_
            targetDuration = breakDuration * 60
            beginSession()
        } else {
            // Break complete — return to idle
            currentMode = .work
            timeRemaining = workDuration * 60
            timerState = .idle
        }
    }
}

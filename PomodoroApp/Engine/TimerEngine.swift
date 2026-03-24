import SwiftUI
import AppKit

extension Notification.Name {
    static let workSessionComplete = Notification.Name("workSessionComplete")
}

@MainActor
final class TimerEngine: ObservableObject {
    enum TimerState: Sendable { case idle, running, paused, onBreak, waitingForUser }
    enum Mode: Sendable { case work, break_ }

    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var currentMode: Mode = .work
    @Published var canResumeWork: Bool = false

    @AppStorage("workDuration") var workDuration: Int = 25 {
        didSet {
            if timerState == .idle && currentMode == .work {
                timeRemaining = workDuration * 60
            }
        }
    }
    @AppStorage("breakDuration") var breakDuration: Int = 5

    unowned let audioEngine: AudioEngine

    private var startDate: Date?
    private var targetDuration: Int = 0
    private var ticker: Timer?
    private var pausedRemaining: Int = 0
    private var savedWorkRemaining: Int = 0

    // MARK: - Init

    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
    }

    // MARK: - Public API

    func start() {
        if timerState == .paused {
            resumeFromPause()
            if currentMode == .work {
                audioEngine.startAmbient()
            }
            return
        }
        canResumeWork = false
        targetDuration = (currentMode == .work ? workDuration : breakDuration) * 60
        beginSession()
        if currentMode == .work {
            audioEngine.startAmbient()
        }
    }

    /// Start with a custom duration in seconds (for testing)
    func startWithDuration(seconds: Int) {
        currentMode = .work
        canResumeWork = false
        targetDuration = seconds
        beginSession()
        audioEngine.startAmbient()
    }

    /// Start break with a custom duration in seconds (for testing)
    func startBreakWithDuration(seconds: Int) {
        ticker?.invalidate()
        ticker = nil
        audioEngine.stopAmbient()
        currentMode = .break_
        canResumeWork = false
        targetDuration = seconds
        beginSession()
    }

    func pause() {
        guard timerState == .running else { return }
        pausedRemaining = timeRemaining
        ticker?.invalidate()
        ticker = nil
        timerState = .paused
        audioEngine.stopAmbient()
    }

    func startBreak() {
        // Save work progress if mid-session
        if currentMode == .work && timerState == .running {
            savedWorkRemaining = timeRemaining
            canResumeWork = true
        }
        ticker?.invalidate()
        ticker = nil
        audioEngine.stopAmbient()
        currentMode = .break_
        targetDuration = breakDuration * 60
        beginSession()
    }

    func resumeWork() {
        guard canResumeWork, savedWorkRemaining > 0 else { return }
        ticker?.invalidate()
        ticker = nil
        currentMode = .work
        canResumeWork = false
        targetDuration = savedWorkRemaining
        beginSession()
        audioEngine.startAmbient()
    }

    func snooze(minutes: Int) {
        ticker?.invalidate()
        ticker = nil
        currentMode = .work
        canResumeWork = false
        targetDuration = minutes * 60
        beginSession()
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        startDate = nil
        audioEngine.stopAmbient()
        currentMode = .work
        canResumeWork = false
        savedWorkRemaining = 0
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
            audioEngine.stopAmbient()
            audioEngine.playChime()
            canResumeWork = false
            timerState = .waitingForUser
            NotificationCenter.default.post(name: .workSessionComplete, object: nil)
        } else {
            // Break complete — resume work if saved, otherwise idle
            if canResumeWork, savedWorkRemaining > 0 {
                currentMode = .work
                canResumeWork = false
                targetDuration = savedWorkRemaining
                savedWorkRemaining = 0
                beginSession()
                audioEngine.startAmbient()
            } else {
                currentMode = .work
                canResumeWork = false
                timeRemaining = workDuration * 60
                timerState = .idle
            }
        }
    }
}

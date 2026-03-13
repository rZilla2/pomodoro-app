import SwiftUI
import AppKit

@MainActor
final class TimerEngine: ObservableObject {
    enum TimerState { case idle, running, paused, onBreak }
    enum Mode { case work, break_ }

    @Published var timerState: TimerState = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var currentMode: Mode = .work

    @AppStorage("workDuration") var workDuration: Int = 25
    @AppStorage("breakDuration") var breakDuration: Int = 5

    private var startDate: Date?
    private var targetDuration: Int = 0
    private var ticker: Timer?
}

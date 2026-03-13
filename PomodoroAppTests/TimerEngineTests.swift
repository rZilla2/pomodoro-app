import Testing
@testable import PomodoroApp

@MainActor
struct TimerEngineTests {

    @Test func startSetsRunningState() {
        let engine = TimerEngine()
        engine.start()
        #expect(engine.timerState == .running)
        engine.stop() // cleanup
    }

    @Test func pauseSetsState() {
        let engine = TimerEngine()
        engine.start()
        engine.pause()
        #expect(engine.timerState == .paused)
        engine.stop() // cleanup
    }

    @Test func stopResetsToIdle() {
        let engine = TimerEngine()
        engine.start()
        engine.stop()
        #expect(engine.timerState == .idle)
        #expect(engine.timeRemaining == engine.workDuration * 60)
    }

    @Test func autoBreakTransition() async throws {
        let engine = TimerEngine()
        engine.startWithDuration(seconds: 1) // 1-second work session
        // Wait for timer to expire and transition
        try await Task.sleep(for: .seconds(2))
        #expect(engine.currentMode == .break_)
        #expect(engine.timerState == .running) // auto-started break
        engine.stop() // cleanup
    }

    @Test func workDurationDefault() {
        let engine = TimerEngine()
        #expect(engine.workDuration == 25)
    }

    @Test func breakDurationDefault() {
        let engine = TimerEngine()
        #expect(engine.breakDuration == 5)
    }

    @Test func clockBasedTime() async throws {
        let engine = TimerEngine()
        engine.startWithDuration(seconds: 10)
        try await Task.sleep(for: .seconds(2))
        // Clock-based: timeRemaining should be approximately 10 - 2 = 8
        // Allow 1 second tolerance for test execution timing
        #expect(engine.timeRemaining <= 9)
        #expect(engine.timeRemaining >= 7)
        engine.stop() // cleanup
    }

    @Test func breakCompletionReturnsToIdle() async throws {
        let engine = TimerEngine()
        // Start a 1-second work session
        engine.startWithDuration(seconds: 1)
        // Wait for work to complete and break to auto-start
        try await Task.sleep(for: .seconds(2))
        #expect(engine.currentMode == .break_)
        // Now force break to be 1 second and wait for it to complete
        engine.startBreakWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        #expect(engine.timerState == .idle)
        #expect(engine.currentMode == .work)
    }
}

import Testing
@testable import PomodoroApp

@MainActor
@Suite struct TimerEngineTests {

    @Test func startSetsRunningState() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        #expect(engine.timerState == .running)
        engine.stop()
    }

    @Test func pauseSetsState() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        engine.pause()
        #expect(engine.timerState == .paused)
        engine.stop()
    }

    @Test func stopResetsToIdle() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        engine.stop()
        #expect(engine.timerState == .idle)
        #expect(engine.timeRemaining == engine.workDuration * 60)
    }

    @Test func autoBreakTransition() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        #expect(engine.currentMode == .break_)
        #expect(engine.timerState == .running)
        engine.stop()
    }

    @Test func workDurationDefault() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        #expect(engine.workDuration == 25)
    }

    @Test func breakDurationDefault() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        #expect(engine.breakDuration == 5)
    }

    @Test func clockBasedTime() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 10)
        try await Task.sleep(for: .seconds(2))
        #expect(engine.timeRemaining <= 9)
        #expect(engine.timeRemaining >= 7)
        engine.stop()
    }

    @Test func breakCompletionReturnsToIdle() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        #expect(engine.currentMode == .break_)
        engine.startBreakWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        #expect(engine.timerState == .idle)
        #expect(engine.currentMode == .work)
    }
}

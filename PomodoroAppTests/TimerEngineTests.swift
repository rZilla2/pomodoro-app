import XCTest
@testable import PomodoroApp

@MainActor
final class TimerEngineTests: XCTestCase {

    func testStartSetsRunningState() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        XCTAssertEqual(engine.timerState, .running)
        engine.stop()
    }

    func testPauseSetsState() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        engine.pause()
        XCTAssertEqual(engine.timerState, .paused)
        engine.stop()
    }

    func testStopResetsToIdle() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.start()
        engine.stop()
        XCTAssertEqual(engine.timerState, .idle)
        XCTAssertEqual(engine.timeRemaining, engine.workDuration * 60)
    }

    func testAutoBreakTransition() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(engine.currentMode, .break_)
        XCTAssertEqual(engine.timerState, .running)
        engine.stop()
    }

    func testWorkDurationDefault() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        XCTAssertEqual(engine.workDuration, 25)
    }

    func testBreakDurationDefault() {
        let engine = TimerEngine(audioEngine: AudioEngine())
        XCTAssertEqual(engine.breakDuration, 5)
    }

    func testClockBasedTime() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 10)
        try await Task.sleep(for: .seconds(2))
        XCTAssertLessThanOrEqual(engine.timeRemaining, 9)
        XCTAssertGreaterThanOrEqual(engine.timeRemaining, 7)
        engine.stop()
    }

    func testBreakCompletionReturnsToIdle() async throws {
        let engine = TimerEngine(audioEngine: AudioEngine())
        engine.startWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(engine.currentMode, .break_)
        engine.startBreakWithDuration(seconds: 1)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(engine.timerState, .idle)
        XCTAssertEqual(engine.currentMode, .work)
    }
}

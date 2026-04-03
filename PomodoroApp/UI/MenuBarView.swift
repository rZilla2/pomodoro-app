import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            Text(modeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 48, weight: .ultraLight))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            HStack(spacing: 16) {
                if timerEngine.timerState == .idle
                    || timerEngine.timerState == .paused
                    || timerEngine.timerState == .waitingForUser {
                    Button("Start") { timerEngine.start() }
                        .keyboardShortcut(.defaultAction)
                }
                if timerEngine.timerState == .running {
                    Button("Pause") { timerEngine.pause() }
                }
                if timerEngine.timerState == .running
                    || timerEngine.timerState == .paused
                    || timerEngine.timerState == .onBreak
                    || timerEngine.timerState == .waitingForUser {
                    Button("Stop") { timerEngine.stop() }
                }
            }
            .controlSize(.large)

            Divider()

            Stepper(
                "Focus: \(timerEngine.workDuration)m",
                value: $timerEngine.workDuration,
                in: 5...120, step: 5
            )
            Stepper(
                "Break: \(timerEngine.breakDuration)m",
                value: $timerEngine.breakDuration,
                in: 1...30, step: 5
            )

            Divider()

            Button("Toggle Panel") {
                (NSApp.delegate as? AppDelegate)?.togglePanel()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 220)
    }

    private var modeLabel: String {
        switch timerEngine.timerState {
        case .idle: return ""
        case .running:
            return timerEngine.currentMode == .work ? "" : "Break"
        case .paused: return "Paused"
        case .onBreak: return "Break"
        case .waitingForUser: return "Time's Up"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

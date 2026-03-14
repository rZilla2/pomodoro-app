import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            // Mode label
            Text(modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)

            // Time display
            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 48, weight: .light, design: .monospaced))

            // Controls
            HStack(spacing: 16) {
                if timerEngine.timerState == .idle || timerEngine.timerState == .paused {
                    Button("Start") {
                        timerEngine.start()
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if timerEngine.timerState == .running {
                    Button("Pause") {
                        timerEngine.pause()
                    }
                }

                if timerEngine.timerState == .running || timerEngine.timerState == .paused || timerEngine.timerState == .onBreak {
                    Button("Stop") {
                        timerEngine.stop()
                    }
                }
            }
            .controlSize(.large)

            Divider()

            // Duration steppers
            VStack(spacing: 8) {
                StepperRow(
                    label: "Focus:",
                    value: $timerEngine.workDuration,
                    range: 5...120,
                    step: 5,
                    accentColor: TokyoNight.blue
                )
                StepperRow(
                    label: "Break:",
                    value: $timerEngine.breakDuration,
                    range: 1...30,
                    step: 5,
                    accentColor: TokyoNight.purple
                )
            }

            Divider()

            Button("Toggle Panel") {
                (NSApp.delegate as? AppDelegate)?.togglePanel()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .foregroundColor(.secondary)
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
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

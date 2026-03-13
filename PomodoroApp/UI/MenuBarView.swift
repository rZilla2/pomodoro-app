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

            // Duration settings
            VStack(spacing: 8) {
                HStack {
                    Text("Work:")
                        .frame(width: 50, alignment: .leading)
                    Stepper(
                        "\(timerEngine.workDuration) min",
                        value: $timerEngine.workDuration,
                        in: 1...120
                    )
                }

                HStack {
                    Text("Break:")
                        .frame(width: 50, alignment: .leading)
                    Stepper(
                        "\(timerEngine.breakDuration) min",
                        value: $timerEngine.breakDuration,
                        in: 1...60
                    )
                }
            }
            .font(.callout)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 240)
    }

    private var modeLabel: String {
        switch timerEngine.timerState {
        case .idle:
            return "Ready"
        case .running:
            return timerEngine.currentMode == .work ? "Working" : "Break"
        case .paused:
            return "Paused"
        case .onBreak:
            return "Break"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

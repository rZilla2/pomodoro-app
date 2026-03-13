import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        VStack(spacing: 12) {
            // Mode label
            Text(modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)

            // Large monospaced countdown
            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .monospacedDigit()

            // Control buttons
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

                if timerEngine.timerState == .idle || (timerEngine.timerState == .running && timerEngine.currentMode == .work) {
                    Button("Break") {
                        timerEngine.startBreak()
                    }
                }

                if timerEngine.timerState == .running || timerEngine.timerState == .paused || timerEngine.timerState == .onBreak {
                    Button("Stop") {
                        timerEngine.stop()
                    }
                }
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)
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

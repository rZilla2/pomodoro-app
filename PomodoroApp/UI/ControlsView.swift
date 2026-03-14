import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine

    private var isCompact: Bool {
        timerEngine.timerState == .running || timerEngine.timerState == .onBreak
    }

    var body: some View {
        VStack(spacing: 6) {
            // Mode label (only when relevant)
            if !modeLabel.isEmpty {
                Text(modeLabel)
                    .font(.caption2)
                    .foregroundColor(TokyoNight.comment)
            }

            // Large monospaced countdown
            Text(formatTime(timerEngine.timeRemaining))
                .font(.system(size: 49, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(TokyoNight.fg)
                .fixedSize()

            if !isCompact {
                // Steppers
                VStack(spacing: 4) {
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

                Spacer().frame(height: 4)

                // Sound picker
                SoundPickerView(audioEngine: audioEngine)

                Spacer().frame(height: 4)
            }

            // Control buttons
            HStack(spacing: 12) {
                if timerEngine.timerState == .idle || timerEngine.timerState == .paused {
                    Button { timerEngine.start() } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(IconButtonStyle(color: TokyoNight.green))
                }

                if timerEngine.timerState == .running {
                    Button { timerEngine.pause() } label: {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(IconButtonStyle(color: TokyoNight.yellow))
                }

                if timerEngine.timerState == .idle || (timerEngine.timerState == .running && timerEngine.currentMode == .work) {
                    Button { timerEngine.startBreak() } label: {
                        Image(systemName: "cup.and.saucer.fill")
                    }
                    .buttonStyle(IconButtonStyle(color: TokyoNight.purple))
                }

                if timerEngine.canResumeWork && timerEngine.currentMode == .break_ {
                    Button { timerEngine.resumeWork() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(IconButtonStyle(color: TokyoNight.blue))
                }

                if timerEngine.timerState == .running || timerEngine.timerState == .paused || timerEngine.timerState == .onBreak {
                    Button { timerEngine.stop() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(IconButtonStyle(color: TokyoNight.red))
                }
            }
        }
        .padding(18)
        .frame(width: isCompact ? nil : 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TokyoNight.bg.opacity(0.75))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isCompact)
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

struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(TokyoNight.comment)
                .frame(width: 32, alignment: .leading)

            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StepperButtonStyle())

            Text("\(value)")
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(TokyoNight.fg)
                .frame(width: 28)
                .multilineTextAlignment(.center)

            Text("m")
                .font(.system(size: 10))
                .foregroundColor(TokyoNight.comment)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StepperButtonStyle())
        }
    }
}

struct StepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? TokyoNight.fg : TokyoNight.comment)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TokyoNight.comment.opacity(configuration.isPressed ? 0.6 : 0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct IconButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(configuration.isPressed ? color.opacity(0.7) : color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
}

struct ThemeButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(configuration.isPressed ? color.opacity(0.7) : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

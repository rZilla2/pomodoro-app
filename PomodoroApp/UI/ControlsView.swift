import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false

    var body: some View {
        VStack(spacing: 0) {
            // --- Compact core (always visible) ---
            VStack(spacing: 6) {
                // Mode label or spacer for hide button alignment
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

                // Tray toggle
                Button { withAnimation(.easeInOut(duration: 0.2)) { trayOpen.toggle() } } label: {
                    Image(systemName: trayOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(TokyoNight.comment)
                        .frame(width: 32, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)
            .padding(.bottom, trayOpen ? 8 : 18)

            // --- Tray (toggled) ---
            if trayOpen {
                VStack(spacing: 8) {
                    Divider()
                        .background(TokyoNight.comment.opacity(0.3))

                    // Sound picker
                    SoundPickerView(audioEngine: audioEngine)

                    // Duration steppers
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

                    Divider()
                        .background(TokyoNight.comment.opacity(0.3))

                    // Quit
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(TrayActionStyle())
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 180)
        .overlay(alignment: .topLeading) {
            Button {
                NotificationCenter.default.post(name: .hidePanelRequested, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(TokyoNight.comment.opacity(0.5))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TokyoNight.bg.opacity(0.75))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Tray action button style

struct TrayActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? TokyoNight.fg : TokyoNight.comment)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TokyoNight.comment.opacity(configuration.isPressed ? 0.5 : 0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Shared components

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

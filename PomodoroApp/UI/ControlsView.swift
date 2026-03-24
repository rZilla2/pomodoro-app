import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false

    var body: some View {
        VStack(spacing: 0) {
            // --- Core (always visible) ---
            VStack(spacing: 8) {
                if !modeLabel.isEmpty {
                    Text(modeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(formatTime(timerEngine.timeRemaining))
                    .font(.system(size: 48, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                HStack(spacing: 8) {
                    if timerEngine.timerState == .idle
                        || timerEngine.timerState == .paused {
                        Button { timerEngine.start() } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }

                    if timerEngine.timerState == .running {
                        Button { timerEngine.pause() } label: {
                            Image(systemName: "pause.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }

                    if timerEngine.timerState == .idle
                        || (timerEngine.timerState == .running
                            && timerEngine.currentMode == .work) {
                        Button { timerEngine.startBreak() } label: {
                            Image(systemName: "cup.and.saucer.fill")
                        }
                        .buttonStyle(.glass)
                    }

                    if timerEngine.canResumeWork
                        && timerEngine.currentMode == .break_ {
                        Button { timerEngine.resumeWork() } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.glass)
                    }

                    if timerEngine.timerState == .running
                        || timerEngine.timerState == .paused
                        || timerEngine.timerState == .onBreak {
                        Button { timerEngine.stop() } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.glass)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        trayOpen.toggle()
                    }
                } label: {
                    Image(systemName: trayOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 32, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 28)
            .padding(.horizontal, 18)
            .padding(.bottom, trayOpen ? 8 : 18)

            // --- Tray (toggled) ---
            if trayOpen {
                VStack(spacing: 10) {
                    Divider()

                    Picker(selection: $audioEngine.selectedSound) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    } label: {
                        Label("Sound", systemImage: "speaker.wave.2")
                    }
                    .pickerStyle(.menu)

                    Stepper(
                        "Focus: \(timerEngine.workDuration)m",
                        value: $timerEngine.workDuration,
                        in: 5...120, step: 5
                    )
                    .font(.system(size: 12))

                    Stepper(
                        "Break: \(timerEngine.breakDuration)m",
                        value: $timerEngine.breakDuration,
                        in: 1...30, step: 5
                    )
                    .font(.system(size: 12))

                    Divider()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 200)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
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

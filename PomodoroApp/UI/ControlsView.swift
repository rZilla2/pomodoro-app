import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Traffic light buttons
                HStack(spacing: 7) {
                    TrafficLightButton(color: .red) {
                        NotificationCenter.default.post(
                            name: .init("hidePanelRequested"), object: nil)
                    }
                    TrafficLightButton(color: .yellow) {
                        NSApp.keyWindow?.miniaturize(NSApp)
                    }
                    TrafficLightButton(color: .green) { }
                    Spacer()
                }
                .padding(.bottom, 4)

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

                GlassEffectContainer(spacing: 8) {
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
                        .controlSize(.large)
                    }

                    if timerEngine.canResumeWork
                        && timerEngine.currentMode == .break_ {
                        Button { timerEngine.resumeWork() } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }

                    if timerEngine.timerState == .running
                        || timerEngine.timerState == .paused
                        || timerEngine.timerState == .onBreak {
                        Button { timerEngine.stop() } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
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
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .padding(.bottom, trayOpen ? 8 : 18)

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

                    DurationRow(
                        label: "Focus",
                        value: $timerEngine.workDuration,
                        range: 5...120,
                        step: 5
                    )
                    DurationRow(
                        label: "Break",
                        value: $timerEngine.breakDuration,
                        range: 1...30,
                        step: 5
                    )

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
        .frame(width: 220)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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

// MARK: - Traffic Light Button

private struct TrafficLightButton: View {
    let color: TrafficLightColor
    let action: () -> Void
    @State private var hovering = false

    enum TrafficLightColor {
        case red, yellow, green
        var fill: Color {
            switch self {
            case .red: return Color(red: 1.0, green: 0.37, blue: 0.34)
            case .yellow: return Color(red: 1.0, green: 0.74, blue: 0.18)
            case .green: return Color(red: 0.16, green: 0.78, blue: 0.25)
            }
        }
        var symbol: String {
            switch self {
            case .red: return "xmark"
            case .yellow: return "minus"
            case .green: return "plus"
            }
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.fill)
                    .frame(width: 12, height: 12)
                if hovering {
                    Image(systemName: color.symbol)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Duration Row (+/- buttons)

private struct DurationRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            GlassEffectContainer(spacing: 4) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            Text("\(value)m")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 32, alignment: .center)
        }
    }
}

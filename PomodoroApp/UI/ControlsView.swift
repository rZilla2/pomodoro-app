import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Traffic lights — always visible
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
                .frame(height: 12)

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

                // Action buttons — icon only, no backgrounds
                HStack(spacing: 12) {
                    if timerEngine.timerState == .idle
                        || timerEngine.timerState == .paused {
                        IconButton(symbol: "play.fill", isPrimary: true) {
                            timerEngine.start()
                        }
                    }

                    if timerEngine.timerState == .running {
                        IconButton(symbol: "pause.fill", isPrimary: true) {
                            timerEngine.pause()
                        }
                    }

                    if timerEngine.timerState == .idle
                        || (timerEngine.timerState == .running
                            && timerEngine.currentMode == .work) {
                        IconButton(symbol: "cup.and.saucer.fill", isPrimary: false) {
                            timerEngine.startBreak()
                        }
                    }

                    if timerEngine.canResumeWork
                        && timerEngine.currentMode == .break_ {
                        IconButton(symbol: "arrow.counterclockwise", isPrimary: false) {
                            timerEngine.resumeWork()
                        }
                    }

                    if timerEngine.timerState == .running
                        || timerEngine.timerState == .paused
                        || timerEngine.timerState == .onBreak {
                        IconButton(symbol: "stop.fill", isPrimary: false) {
                            timerEngine.stop()
                        }
                    }
                }

                // Tray toggle
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

                    HStack(spacing: 6) {
                        Button {
                            audioEngine.toggleMute()
                        } label: {
                            Image(systemName: audioEngine.isMuted
                                  ? "speaker.slash.fill"
                                  : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(audioEngine.isMuted ? .secondary : .primary)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Picker(selection: $audioEngine.selectedSound) {
                            ForEach(AmbientSound.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        } label: {
                            Text("Sound")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // Duration rows: Label  [−][+]  Value
                    DurationRow(
                        label: "Focus",
                        value: $timerEngine.workDuration,
                        range: 1...120,
                        timerEngine: timerEngine,
                        isActiveMode: timerEngine.currentMode == .work
                    )
                    DurationRow(
                        label: "Break",
                        value: $timerEngine.breakDuration,
                        range: 1...30,
                        timerEngine: timerEngine,
                        isActiveMode: timerEngine.currentMode == .break_
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

// MARK: - Icon Button (no background, hover highlight)

private struct IconButton: View {
    let symbol: String
    let isPrimary: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isPrimary ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isPrimary
                              ? Color.accentColor
                              : (hovering ? .white.opacity(0.1) : .clear))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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

// MARK: - Duration Row: Label  [+][−]  ▾step  (value when idle)

private struct DurationRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @ObservedObject var timerEngine: TimerEngine
    let isActiveMode: Bool
    @State private var plusHover = false
    @State private var minusHover = false
    @State private var stepSize: Int = 5
    @State private var showUnderflowAlert = false

    private var isRunning: Bool {
        isActiveMode && (timerEngine.timerState == .running || timerEngine.timerState == .paused)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(width: 38, alignment: .leading)

            // − then +
            HStack(spacing: 2) {
                Button { handleMinus() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(minusHover ? .white.opacity(0.1) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { minusHover = $0 }

                Button { handlePlus() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(plusHover ? .white.opacity(0.1) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { plusHover = $0 }
            }

            // Step size picker (dropdown)
            Picker(selection: $stepSize) {
                Text("1m").tag(1)
                Text("5m").tag(5)
                Text("10m").tag(10)
            } label: {
                EmptyView()
            }
            .pickerStyle(.menu)
            .frame(width: 52)
            .controlSize(.small)

            // Duration value — only when idle
            if !isRunning {
                Text("\(value)m")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
        .alert("End session?", isPresented: $showUnderflowAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Session") {
                timerEngine.forceAdjustTime(bySeconds: -(stepSize * 60))
                value = max(range.lowerBound, value - stepSize)
            }
        }
    }

    private func handlePlus() {
        if isRunning {
            _ = timerEngine.adjustTime(bySeconds: stepSize * 60)
        }
        value = min(range.upperBound, value + stepSize)
    }

    private func handleMinus() {
        if isRunning {
            let wouldSucceed = timerEngine.adjustTime(bySeconds: -(stepSize * 60))
            if wouldSucceed {
                value = max(range.lowerBound, value - stepSize)
            } else {
                showUnderflowAlert = true
            }
        } else {
            value = max(range.lowerBound, value - stepSize)
        }
    }
}

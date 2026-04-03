import ServiceManagement
import SwiftUI

struct ControlsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var audioEngine: AudioEngine
    @State private var trayOpen = false
    @State private var scrollFeedback: Int? = nil
    @State private var feedbackTask: Task<Void, Never>?
    @State private var timerHovering = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Traffic lights — always visible, native 8px inset
                HStack(spacing: 7) {
                    TrafficLightButton(color: .red) {
                        NotificationCenter.default.post(
                            name: .hidePanelRequested, object: nil)
                    }
                    TrafficLightButton(color: .yellow) {
                        NotificationCenter.default.post(
                            name: .hidePanelRequested, object: nil)
                    }
                    TrafficLightButton(color: .green) { }
                    Spacer()
                }
                .frame(height: 12)
                .padding(.horizontal, -6)

                if !modeLabel.isEmpty {
                    Text(modeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Scrollable timer display
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        // Up arrow hint
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(timerHovering ? 0.35 : 0))
                            .animation(.easeOut(duration: 0.2), value: timerHovering)

                        Text(formatTime(timerEngine.timeRemaining))
                            .font(.system(size: 48, weight: .ultraLight))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())

                        // Down arrow hint
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(timerHovering ? 0.35 : 0))
                            .animation(.easeOut(duration: 0.2), value: timerHovering)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                timerHovering
                                    ? Color.white.opacity(0.25)
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(timerHovering ? Color.white.opacity(0.04) : .clear)
                    )
                    .onScrollWheel(isHovering: $timerHovering) { delta in
                        handleScroll(delta: delta)
                    }

                    // Scroll feedback badge
                    if let fb = scrollFeedback {
                        Text(fb > 0 ? "+\(fb):00" : "\(fb):00")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(fb > 0 ? .green : .red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(fb > 0
                                          ? Color.green.opacity(0.15)
                                          : Color.red.opacity(0.15))
                            )
                            .offset(x: 8, y: -8)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: scrollFeedback)

                // Action buttons — icon only, no backgrounds
                HStack(spacing: 12) {
                    if timerEngine.timerState == .idle
                        || timerEngine.timerState == .paused
                        || timerEngine.timerState == .waitingForUser {
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
                        || timerEngine.timerState == .waitingForUser
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
                        || timerEngine.timerState == .onBreak
                        || timerEngine.timerState == .waitingForUser {
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
                                .font(.system(size: 12, weight: .light))
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

                    Divider()

                    LaunchAtLoginToggle()

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
        .onDisappear {
            feedbackTask?.cancel()
            feedbackTask = nil
        }
    }

    // MARK: - Scroll Handling

    private func handleScroll(delta: CGFloat) {
        // delta > 0 = scroll down = add time; delta < 0 = scroll up = subtract
        let seconds = delta > 0 ? 60 : -60
        let newRemaining = timerEngine.timeRemaining + seconds
        guard newRemaining > 0 else { return }

        let isRunning = timerEngine.timerState == .running || timerEngine.timerState == .paused

        if isRunning {
            let succeeded = timerEngine.adjustTime(bySeconds: seconds)
            if !succeeded { return }
        } else {
            timerEngine.timeRemaining = newRemaining
        }

        // Keep base duration in sync
        let newMinutes = Int(round(Double(newRemaining) / 60.0))
        if timerEngine.currentMode == .work {
            guard (1...120).contains(newMinutes) else { return }
            timerEngine.workDuration = newMinutes
        } else {
            guard (1...30).contains(newMinutes) else { return }
            timerEngine.breakDuration = newMinutes
        }

        showFeedback(seconds > 0 ? 1 : -1)
    }

    private func showFeedback(_ delta: Int) {
        scrollFeedback = delta
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            scrollFeedback = nil
        }
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

// MARK: - Scroll Wheel Modifier

private struct ScrollWheelModifier: ViewModifier {
    let handler: (CGFloat) -> Void
    @Binding var isHovering: Bool
    private static let threshold: CGFloat = 15

    func body(content: Content) -> some View {
        content.overlay(
            ScrollWheelView(threshold: Self.threshold, handler: handler, isHovering: $isHovering)
        )
    }
}

private struct ScrollWheelView: NSViewRepresentable {
    let threshold: CGFloat
    let handler: (CGFloat) -> Void
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.threshold = threshold
        view.handler = handler
        view.hoverCallback = { hovering in
            DispatchQueue.main.async { self.isHovering = hovering }
        }
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.handler = handler
        nsView.hoverCallback = { hovering in
            DispatchQueue.main.async { self.isHovering = hovering }
        }
    }
}

final class ScrollWheelNSView: NSView {
    var threshold: CGFloat = 15
    var handler: ((CGFloat) -> Void)?
    var hoverCallback: ((Bool) -> Void)?
    private var accumulated: CGFloat = 0
    private var scrollMonitor: Any?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hoverCallback?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverCallback?(false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            guard scrollMonitor == nil else { return }
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    self.accumulated += event.scrollingDeltaY
                    if abs(self.accumulated) >= self.threshold {
                        let direction: CGFloat = self.accumulated > 0 ? -1 : 1
                        self.accumulated = 0
                        self.handler?(direction)
                    }
                    return nil
                }
                return event
            }
        } else {
            if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
            scrollMonitor = nil
        }
    }

    override func removeFromSuperview() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        super.removeFromSuperview()
    }
}

private extension View {
    func onScrollWheel(isHovering: Binding<Bool>, handler: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(handler: handler, isHovering: isHovering))
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

// MARK: - Launch at Login Toggle

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label("Launch at Login", systemImage: "arrow.right.circle")
                .font(.system(size: 11))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .foregroundStyle(.secondary)
        .onChange(of: isEnabled) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
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

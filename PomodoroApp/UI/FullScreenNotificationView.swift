import SwiftUI

struct FullScreenNotificationView: View {
    let onDismiss: @MainActor () -> Void
    let onSnooze: @MainActor () -> Void

    private var backgroundImage: NSImage? {
        let path = "/System/Library/Desktop Pictures/.thumbnails/Monterey Graphic Dark.heic"
        return NSImage(contentsOfFile: path)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1))
                }

                VStack(spacing: 0) {
                    Image(systemName: "timer")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 28)

                    Text("Time's Up")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 10)

                    Text("Your focus session has ended.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, 44)

                    HStack(spacing: 14) {
                        Button { onSnooze() } label: {
                            Text("Snooze 5m")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)

                        Button { onDismiss() } label: {
                            Text("Dismiss")
                                .frame(minWidth: 120)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                    .padding(.bottom, 32)

                    HStack(spacing: 4) {
                        KeyboardHint(key: "Return", label: "to snooze")
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                            .font(.system(size: 11))
                        KeyboardHint(key: "Esc", label: "to dismiss")
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            onSnooze()
            return .handled
        }
    }
}

private struct KeyboardHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.05))
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.white.opacity(0.2))
    }
}

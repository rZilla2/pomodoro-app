import SwiftUI

struct FullScreenNotificationView: View {
    let onDismiss: @MainActor () -> Void
    let onRestart: @MainActor () -> Void
    let onAddTime: @MainActor (Int) -> Void
    let onBreak: @MainActor (Int) -> Void

    private let quote = Self.quotes.randomElement() ?? Self.quotes[0]

    private var backgroundColor: Color {
        Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1))
    }

    private static let quotes: [(text: String, author: String)] = [
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("It is not enough to be busy. The question is: what are we busy about?", "Henry David Thoreau"),
        ("Focus on being productive instead of busy.", "Tim Ferriss"),
        ("Until we can manage time, we can manage nothing else.", "Peter Drucker"),
        ("Action is the foundational key to all success.", "Pablo Picasso"),
        ("Amateurs sit and wait for inspiration. The rest of us just get up and go to work.", "Stephen King"),
        ("You don't have to see the whole staircase, just take the first step.", "Martin Luther King Jr."),
        ("The way to get started is to quit talking and begin doing.", "Walt Disney"),
        ("Start where you are. Use what you have. Do what you can.", "Arthur Ashe"),
        ("Discipline is choosing between what you want now and what you want most.", "Abraham Lincoln"),
        ("Small deeds done are better than great deeds planned.", "Peter Marshall"),
        ("Don't count the days, make the days count.", "Muhammad Ali"),
        ("Energy and persistence conquer all things.", "Benjamin Franklin"),
        ("Either you run the day or the day runs you.", "Jim Rohn"),
        ("The best time to plant a tree was 20 years ago. The second best time is now.", "Chinese Proverb"),
        ("Done is better than perfect.", "Sheryl Sandberg"),
        ("What we fear doing most is usually what we most need to do.", "Tim Ferriss"),
        ("If you spend too much time thinking about a thing, you'll never get it done.", "Bruce Lee"),
        ("Simplicity is the ultimate sophistication.", "Leonardo da Vinci"),
        ("You miss 100% of the shots you don't take.", "Wayne Gretzky"),
        ("The only way to do great work is to love what you do.", "Steve Jobs"),
        ("Be yourself; everyone else is already taken.", "Oscar Wilde"),
        ("In the middle of difficulty lies opportunity.", "Albert Einstein"),
        ("A year from now you'll wish you had started today.", "Karen Lamb"),
        ("The harder I work, the luckier I get.", "Samuel Goldwyn"),
        ("Do what you can, with what you have, where you are.", "Theodore Roosevelt"),
        ("Knowing is not enough; we must apply.", "Johann Wolfgang von Goethe"),
        ("It always seems impossible until it's done.", "Nelson Mandela"),
        ("Well done is better than well said.", "Benjamin Franklin"),
        ("Perseverance is not a long race; it is many short races one after the other.", "Walter Elliot"),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundColor

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
                        .padding(.bottom, 24)

                    VStack(spacing: 6) {
                        Text("\u{201C}\(quote.text)\u{201D}")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                        Text("— \(quote.author)")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: 420)
                    .padding(.bottom, 44)

                    // Keep going
                    GlassEffectContainer(spacing: 14) {
                        Button { onRestart() } label: {
                            Text("Restart")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)

                        Button { onAddTime(5) } label: {
                            Text("+5 min")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)

                        Button { onAddTime(10) } label: {
                            Text("+10 min")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                    .padding(.bottom, 14)

                    // Take a break or dismiss
                    GlassEffectContainer(spacing: 14) {
                        Button { onBreak(5) } label: {
                            Text("Break 5m")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)

                        Button { onBreak(10) } label: {
                            Text("Break 10m")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)

                        Button { onDismiss() } label: {
                            Text("Dismiss")
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                    .padding(.bottom, 32)

                    HStack(spacing: 4) {
                        KeyboardHint(key: "Return", label: "restart")
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                            .font(.system(size: 11))
                        KeyboardHint(key: "+", label: "+5 min")
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                            .font(.system(size: 11))
                        KeyboardHint(key: "Esc", label: "dismiss")
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
            onRestart()
            return .handled
        }
        .onKeyPress("+") {
            onAddTime(5)
            return .handled
        }
        .onKeyPress("=") {
            onAddTime(5)
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

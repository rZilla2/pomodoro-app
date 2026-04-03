import AVFoundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.rzilla.pomodoro", category: "audio")

// MARK: - AmbientSound

enum AmbientSound: String, CaseIterable, Identifiable, Sendable {
    case forest
    case ocean
    case thunderstorm

    var id: String { rawValue }

    var filename: String { rawValue }

    var displayName: String {
        switch self {
        case .forest:       return "Forest"
        case .ocean:        return "Ocean"
        case .thunderstorm: return "Thunderstorm"
        }
    }
}

// MARK: - AudioEngine

@MainActor
final class AudioEngine: ObservableObject {

    @Published var selectedSound: AmbientSound {
        didSet {
            UserDefaults.standard.set(selectedSound.rawValue, forKey: "selectedSound")
            if ambientPlayer?.isPlaying == true {
                startAmbient()
            }
        }
    }
    @Published var isMuted: Bool = true

    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    init() {
        if let raw = UserDefaults.standard.string(forKey: "selectedSound"),
           let sound = AmbientSound(rawValue: raw) {
            selectedSound = sound
        } else {
            selectedSound = .forest
        }
    }

    // MARK: - Public API

    func startAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil

        guard let url = Bundle.module.url(forResource: selectedSound.filename, withExtension: "m4a") else {
            assertionFailure("AudioEngine: missing bundle resource for \(selectedSound.filename).m4a")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // infinite loop
            player.volume = isMuted ? 0 : 0.25
            player.prepareToPlay()
            player.play()
            ambientPlayer = player
        } catch {
            logger.error("Failed to start ambient: \(error.localizedDescription)")
        }
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func playChime() {
        chimePlayer?.stop()
        chimePlayer = nil

        // Use sandbox-safe NSSound API for system sounds
        if let glass = NSSound(named: "Glass") {
            glass.play()
            return
        }

        // Fallback to bundled chime
        guard let url = Bundle.module.url(forResource: "chime", withExtension: "m4a") else {
            logger.warning("No chime sound available — neither system Glass nor bundled chime found")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            player.play()
            chimePlayer = player
        } catch {
            logger.error("Failed to play bundled chime: \(error.localizedDescription)")
        }
    }

    func toggleMute() {
        isMuted.toggle()
        ambientPlayer?.volume = isMuted ? 0 : 0.25
    }

}

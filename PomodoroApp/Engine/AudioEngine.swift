import AVFoundation
import SwiftUI

// MARK: - AmbientSound

enum AmbientSound: String, CaseIterable, Identifiable, Sendable {
    case rain
    case ocean
    case forest
    case fireplace
    case whitenoise
    case coffeeshop

    var id: String { rawValue }

    var filename: String { rawValue }

    var displayName: String {
        switch self {
        case .rain:       return "Rain"
        case .ocean:      return "Ocean"
        case .forest:     return "Forest"
        case .fireplace:  return "Fireplace"
        case .whitenoise: return "White Noise"
        case .coffeeshop: return "Coffee Shop"
        }
    }
}

// MARK: - AudioEngine

@MainActor
final class AudioEngine: ObservableObject {

    @Published var selectedSound: AmbientSound

    private var ambientPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?

    init() {
        if let raw = UserDefaults.standard.string(forKey: "selectedSound"),
           let sound = AmbientSound(rawValue: raw) {
            selectedSound = sound
        } else {
            selectedSound = .rain
        }
    }

    // MARK: - Public API

    func startAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil

        guard let url = Bundle.main.url(forResource: selectedSound.filename, withExtension: "m4a") else {
            assertionFailure("AudioEngine: missing bundle resource for \(selectedSound.filename).m4a")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // infinite loop
            player.volume = 0.7
            player.prepareToPlay()
            player.play()
            ambientPlayer = player
        } catch {
            print("AudioEngine: failed to start ambient – \(error)")
        }
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func playChime() {
        chimePlayer?.stop()
        chimePlayer = nil

        guard let url = Bundle.main.url(forResource: "chime", withExtension: "m4a") else {
            assertionFailure("AudioEngine: missing bundle resource for chime.m4a")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0 // play once
            player.prepareToPlay()
            player.play()
            chimePlayer = player
        } catch {
            print("AudioEngine: failed to play chime – \(error)")
        }
    }

    func select(_ sound: AmbientSound) {
        selectedSound = sound
        UserDefaults.standard.set(sound.rawValue, forKey: "selectedSound")
        if ambientPlayer?.isPlaying == true {
            startAmbient() // switch track immediately
        }
    }
}

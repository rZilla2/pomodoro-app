import SwiftUI

struct SoundPickerView: View {
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 10))
                .foregroundColor(TokyoNight.comment)

            Menu(audioEngine.selectedSound.displayName) {
                ForEach(AmbientSound.allCases) { sound in
                    Button(sound.displayName) {
                        audioEngine.select(sound)
                    }
                }
            }
            .font(.system(size: 11))
            .foregroundColor(TokyoNight.fg)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

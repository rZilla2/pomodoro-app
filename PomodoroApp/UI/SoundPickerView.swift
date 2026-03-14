import SwiftUI

struct SoundPickerView: View {
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 10))
                .foregroundColor(TokyoNight.comment)

            Menu {
                ForEach(AmbientSound.allCases) { sound in
                    Button(sound.displayName) {
                        audioEngine.select(sound)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(audioEngine.selectedSound.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(TokyoNight.fg)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(TokyoNight.comment)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

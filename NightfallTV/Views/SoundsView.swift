import SwiftUI

struct SoundsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                PageHeading(eyebrow: "SOUND, SOFTLY", title: settings.l("让世界，慢一点。", "Let the world slow down."), subtitle: settings.l("4 种真实自然录音，2 种柔和噪音。离线播放，默认静音。", "Four nature recordings, two gentle noises. Offline, silent by default."))
                HStack(spacing: 32) {
                    QuietButton(title: settings.l("停止声景", "Stop sound"), symbol: "speaker.slash.fill", id: "stop-sound") { sound.stop() }
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $settings.value.soundVolume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .frame(width: 400).accessibilityIdentifier("sound-volume")
                    Text(sound.selected.map { settings.l("正在播放：", "Playing: ") + $0.title(settings.value.english) } ?? settings.l("当前静音", "Currently silent"))
                        .font(.callout).foregroundStyle(Palette.accent).accessibilityIdentifier("sound-status")
                    Spacer()
                }.focusSection()
                if let error = sound.error { Text(error).font(.callout).foregroundStyle(.orange) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 32) {
                    ForEach(SoundKind.allCases) { kind in
                        Button {
                            if sound.selected == kind { sound.stop() } else { sound.play(kind, volume: settings.value.soundVolume) }
                            playback.interaction()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                soundArtwork(for: kind).aspectRatio(1.75, contentMode: .fit)
                                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 16) {
                                    Image(systemName: kind.symbol).font(.title2).foregroundStyle(Palette.accent)
                                    HStack {
                                        Text(kind.title(settings.value.english)).font(.title2)
                                        Spacer()
                                        Image(systemName: sound.selected == kind ? "stop.circle.fill" : "play.circle").font(.title2)
                                    }
                                    Text(kind.subtitle(settings.value.english)).font(.caption).foregroundStyle(Palette.muted)
                                }.padding(32)
                            }.clipShape(RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(ArtworkButtonStyle()).accessibilityIdentifier("sound-\(kind.rawValue)")
                            .accessibilityLabel(kind.title(settings.value.english) + " · " + (sound.selected == kind ? settings.l("停止", "Stop") : settings.l("播放", "Play")))
                    }
                }
                QuietButton(title: settings.l("带着声景进入黑屏", "Keep sound, go dark"), symbol: "moon.zzz.fill", id: "sound-black") { playback.start(.black) }
            }.padding(80)
        }.onChange(of: settings.value.soundVolume) { _, volume in sound.setVolume(volume) }
    }

    /// 雨、海浪和炉火使用对应实拍；溪流与噪音使用符号背景，避免无关景色误导。
    @ViewBuilder
    private func soundArtwork(for sound: SoundKind) -> some View {
        switch sound {
        case .rain: SceneArtwork(kind: .rain).opacity(0.6)
        case .ocean: SceneArtwork(kind: .ocean).opacity(0.6)
        case .fire: SceneArtwork(kind: .ember).opacity(0.6)
        case .stream, .pink, .brown:
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [sound == .stream ? Color(red: 0.04, green: 0.2, blue: 0.2) : Palette.accent.opacity(0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: sound == .stream ? "water.waves" : "waveform")
                    .font(.system(size: 110, weight: .ultraLight)).foregroundStyle(Palette.accent.opacity(0.18)).padding(32)
            }
        }
    }
}

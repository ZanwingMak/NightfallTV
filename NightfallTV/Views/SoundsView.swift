import SwiftUI

struct SoundsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                PageHeading(eyebrow: "SOUND, SOFTLY", title: settings.l("让世界，慢一点。", "Let the world slow down."), subtitle: settings.l("6 种原创离线声景。默认安静，不打断你自己的音乐。", "Six original offline soundscapes. Silent by default, gentle with your music."))
                HStack(spacing: 32) {
                    QuietButton(title: settings.l("停止声景", "Stop sound"), symbol: "speaker.slash.fill", id: "stop-sound") { sound.stop() }
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $settings.value.soundVolume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .frame(width: 400).accessibilityIdentifier("sound-volume")
                    Text(sound.selected.map { settings.l("正在播放：", "Playing: ") + $0.title(settings.value.english) } ?? settings.l("当前静音", "Currently silent"))
                        .font(.callout).foregroundStyle(Palette.accent).accessibilityIdentifier("sound-status")
                    Spacer()
                }
                if let error = sound.error { Text(error).font(.callout).foregroundStyle(.orange) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 32) {
                    ForEach(SoundKind.allCases) { kind in
                        Button {
                            if sound.selected == kind { sound.stop() } else { sound.play(kind, volume: settings.value.soundVolume) }
                            playback.interaction()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                SceneArtwork(kind: artwork(for: kind)).aspectRatio(1.75, contentMode: .fit).opacity(0.6)
                                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 16) {
                                    Image(systemName: kind.symbol).font(.title2).foregroundStyle(Palette.accent)
                                    HStack {
                                        Text(kind.title(settings.value.english)).font(.title2)
                                        Spacer()
                                        Image(systemName: sound.selected == kind ? "pause.circle.fill" : "play.circle").font(.title2)
                                    }
                                    Text(settings.l("离线 · 无缝循环", "Offline · seamless loop")).font(.caption).foregroundStyle(Palette.muted)
                                }.padding(32)
                            }.clipShape(RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(ArtworkButtonStyle()).accessibilityIdentifier("sound-\(kind.rawValue)")
                    }
                }
                QuietButton(title: settings.l("带着声景进入黑屏", "Keep sound, go dark"), symbol: "moon.zzz.fill", id: "sound-black") { playback.start(.black) }
            }.padding(80)
        }.onChange(of: settings.value.soundVolume) { _, volume in sound.setVolume(volume) }
    }

    /// 为声景分配静态实拍预览；预览不启动视频解码或音频。
    private func artwork(for sound: SoundKind) -> SceneKind {
        switch sound {
        case .rain: return .rain
        case .ocean: return .ocean
        case .stream: return .aurora
        case .fire: return .ember
        case .pink: return .prism
        case .brown: return .dunes
        }
    }
}

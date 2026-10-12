import SwiftUI

struct SoundsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @State private var picture: SceneKind?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                PageHeading(eyebrow: "SOUND, SOFTLY", title: settings.l("让世界，慢一点。", "Let the world slow down."), subtitle: settings.l("8 种真实自然录音，2 种柔和噪音。听声音，看风景，或者完全黑屏。", "Eight nature recordings, two gentle noises. Watch a scene or listen in absolute black."))
                HStack(spacing: 32) {
                    QuietButton(title: settings.l("停止声景", "Stop sound"), symbol: "speaker.slash.fill", id: "stop-sound") { sound.stop() }
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $settings.value.soundVolume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .frame(width: 400).accessibilityIdentifier("sound-volume")
                    Text(sound.selected.map { settings.l("正在播放：", "Playing: ") + $0.title(settings.value.english) } ?? settings.l("当前静音", "Currently silent"))
                        .font(.callout).foregroundStyle(Palette.accent).accessibilityIdentifier("sound-status")
                    Spacer()
                }.focusSection()
                HStack(spacing: 24) {
                    ChoicePicker(title: settings.l("搭配画面", "Picture"), selection: $picture,
                                 options: [(nil, settings.l("随声景推荐", "Suggested"))] + SceneKind.allCases.filter { $0 != .black }.map { (Optional($0), $0.title(settings.value.english)) })
                        .frame(width: 580).accessibilityIdentifier("sound-picture")
                    QuietButton(title: settings.l("打开画面", "Picture on"), symbol: "tv", id: "sound-visual") {
                        guard let selected = sound.selected else { return }
                        playback.start(picture ?? selected.visualScene)
                    }.disabled(sound.selected == nil)
                    QuietButton(title: settings.l("关闭画面 · 继续听", "Picture off · keep listening"), symbol: "moon.zzz.fill", id: "sound-black") { playback.start(.black) }
                        .disabled(sound.selected == nil)
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
                Text(settings.l("选择声景开始试听，再打开或关闭画面。画面与录音为独立素材；纯黑模式不显示时钟或提示。", "Select a sound to preview, then turn the picture on or off. Footage and recordings are separate assets. Black mode has no clock or overlays.")).font(.caption).foregroundStyle(Palette.muted)
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
        case .birds, .wind: SceneArtwork(kind: .prism).opacity(0.5)
        case .crickets: SceneArtwork(kind: .stars).opacity(0.6)
        case .waterfall: SceneArtwork(kind: .waterfall).opacity(0.6)
        case .stream, .pink, .brown:
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [sound == .stream ? Color(red: 0.04, green: 0.2, blue: 0.2) : Palette.accent.opacity(0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: sound == .stream ? "water.waves" : "waveform")
                    .font(.system(size: 110, weight: .ultraLight)).foregroundStyle(Palette.accent.opacity(0.18)).padding(32)
            }
        }
    }
}

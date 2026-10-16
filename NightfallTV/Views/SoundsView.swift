import SwiftUI

struct SoundsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @EnvironmentObject private var downloads: DownloadStore
    @State private var showingDownloads = false
    @State private var downloadID: String?
    @State private var picture: SceneKind?
    @State private var showingMixer = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                PageHeading(eyebrow: "SOUND, SOFTLY", title: settings.l("让世界，慢一点。", "Let the world slow down."), subtitle: settings.l("白噪音、自然声景与睡前片刻。选择声音，放松下来。", "White noise, nature sounds and a moment to unwind. Choose your quiet."))
                HStack(spacing: 24) {
                    QuietButton(title: settings.l("静心 · 10 分钟", "Unwind · 10 min"), symbol: "leaf", id: "home-meditation") {
                        playback.startWithSound(.black, sound: .stream)
                        playback.setSleep(10)
                    }
                    QuietButton(title: settings.l("下载更多高音质录音", "Download more lossless recordings"), symbol: "arrow.down.circle", id: "sound-downloads") { downloadID = nil; showingDownloads = true }
                    Spacer()
                }.focusSection()
                HStack(spacing: 32) {
                    QuietButton(title: settings.l("停止声景", "Stop sound"), symbol: "speaker.slash.fill", id: "stop-sound") { sound.stop() }
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $settings.value.soundVolume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .frame(width: 400).accessibilityIdentifier("sound-volume")
                    QuietButton(title: settings.l("混合声景", "Mix sounds"), symbol: "slider.horizontal.3", id: "sound-mixer") { showingMixer = true }
                    Text(sound.layers.isEmpty ? settings.l("当前静音", "Currently silent") : settings.l("正在播放：", "Playing: ") + sound.title(settings.language))
                        .font(.callout).foregroundStyle(Palette.accent).lineLimit(2).accessibilityIdentifier("sound-status")
                    Spacer()
                }.focusSection()
                HStack(spacing: 24) {
                    ChoicePicker(title: settings.l("搭配画面", "Picture"), selection: $picture,
                                 options: [(nil, settings.l("随声景推荐", "Suggested"))] + SceneKind.available.filter { $0 != .black }.map { (Optional($0), $0.title(settings.language)) })
                        .frame(width: 580).accessibilityIdentifier("sound-picture")
                    QuietButton(title: settings.l("打开画面", "Picture on"), symbol: "tv", id: "sound-visual") {
                        guard let selected = sound.selected else { return }
                        playback.start(picture ?? selected.visualScene)
                    }.disabled(sound.selected == nil)
                    QuietButton(title: settings.l("关闭画面 · 继续听", "Picture off · keep listening"), symbol: "moon.zzz.fill", id: "sound-black") { playback.startDarkListening() }.disabled(sound.selected == nil)
                    Spacer()
                }.focusSection()
                if let error = sound.error { Text(error).font(.callout).foregroundStyle(.orange) }
                FocusGrid(SoundKind.allCases.filter { !$0.isDownload }) { kind in soundCard(kind) }
                PageHeading(eyebrow: "A WIDER WORLD", title: settings.l("更多无损录音", "More lossless recordings"), subtitle: settings.l("先选喜欢的，再免费下载。", "Choose a favorite, then download it free."))
                FocusGrid(SoundKind.allCases.filter(\.isDownload)) { kind in soundCard(kind) }
                Text(settings.l("请先选择声景。打开画面时，小窗预览旁始终显示播放控制；关闭画面后声音继续。停止声音即结束会话。不提供独立视频播放、照片画廊或时钟模式。", "Choose a sound first. Picture on shows a small preview with playback controls. Picture off keeps the audio playing. Stopping sound ends the session. There is no standalone video, photo gallery or clock mode.")).font(.caption).foregroundStyle(Palette.muted)
            }.padding(80)
        }.onChange(of: settings.value.soundVolume) { _, volume in sound.setVolume(volume) }
            .sheet(isPresented: $showingDownloads) { DownloadsView(filter: .audio, assetID: downloadID) }
            .sheet(isPresented: $showingMixer, onDismiss: { playback.choosingOptions = false; playback.interaction() }) { SoundMixerView() }
    }

    /// 未下载的录音展示规格并打开对应下载项，只有可播放的录音才会开始试听。
    private func soundCard(_ kind: SoundKind) -> some View {
        Button {
            if !kind.isAvailable { downloadID = DownloadAsset.sound(kind)?.id; showingDownloads = true; return }
            if sound.layers.contains(where: { $0.sound == kind }) { playback.toggleSoundLayer(kind) }
            else { sound.play(kind, volume: settings.value.soundVolume) }
            playback.interaction()
        } label: {
            ZStack(alignment: .bottomLeading) {
                soundArtwork(for: kind).aspectRatio(1.75, contentMode: .fit)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: kind.symbol).font(.title2).foregroundStyle(Palette.accent)
                    HStack {
                        Text(kind.title(settings.language)).font(.title2)
                        Spacer()
                        Image(systemName: !kind.isAvailable ? "arrow.down.circle" : (sound.layers.contains(where: { $0.sound == kind }) ? "stop.circle.fill" : "play.circle")).font(.title2)
                    }
                    Text(kind.subtitle(settings.language)).font(.caption).foregroundStyle(Palette.muted)
                }.padding(32)
                if kind.isDownload {
                    VStack {
                        HStack {
                            Spacer()
                            Label(downloads.ready.contains(kind.rawValue) ? settings.l("已下载", "Downloaded") : settings.l("免费下载", "Download free"), systemImage: downloads.ready.contains(kind.rawValue) ? "checkmark.circle.fill" : "arrow.down.circle")
                                .font(.caption2).padding(10).background(.black.opacity(0.75), in: Capsule())
                        }
                        Spacer()
                    }.padding(16)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(ArtworkButtonStyle()).accessibilityIdentifier("sound-\(kind.rawValue)")
            .accessibilityLabel(kind.title(settings.language) + " · " + (!kind.isAvailable ? settings.l("免费下载", "Download free") : (sound.layers.contains(where: { $0.sound == kind }) ? settings.l("移除此声层", "Remove layer") : settings.l("单独播放", "Play alone"))))
    }

    /// 雨、海浪和炉火使用对应实拍；溪流与噪音使用符号背景，避免无关景色误导。
    @ViewBuilder
    private func soundArtwork(for sound: SoundKind) -> some View {
        switch sound {
        case .rain, .thunder: SceneArtwork(kind: .rain).opacity(0.6)
        case .ocean: SceneArtwork(kind: .ocean).opacity(0.6)
        case .fire: SceneArtwork(kind: .ember).opacity(0.6)
        case .birds, .wind, .parkbirds, .parkwind: SceneArtwork(kind: .prism).opacity(0.5)
        case .crickets: SceneArtwork(kind: .stars).opacity(0.6)
        case .waterfall: SceneArtwork(kind: .waterfall).opacity(0.6)
        case .stream, .pink, .brown, .white, .parkriver:
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [(sound == .stream || sound == .parkriver) ? Color(red: 0.04, green: 0.2, blue: 0.2) : Palette.accent.opacity(0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: (sound == .stream || sound == .parkriver) ? "water.waves" : "waveform")
                    .font(.system(size: 110, weight: .ultraLight)).foregroundStyle(Palette.accent.opacity(0.18)).padding(32)
            }
        }
    }
}

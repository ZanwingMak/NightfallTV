import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var screenFocused: Bool
    @FocusState private var controlFocused: Bool
    @State private var showingMixer = false
    @State private var savingRoutine = false

    var body: some View {
        ZStack {
            screen
                .focusable(!playback.controlsVisible).focusEffectDisabled().focused($screenFocused)
                .onTapGesture { playback.showControls() }
                .onMoveCommand { direction in
                    playback.interaction()
                    guard !playback.controlsVisible, playback.effectiveScene != .black else { return }
                    switch direction {
                    case .left: playback.step(forward: false)
                    case .right: playback.step(forward: true)
                    default: playback.showControls()
                    }
                }
                .accessibilityIdentifier(playback.effectiveScene == .black ? "black-screen" : "playing-\(playback.effectiveScene.rawValue)")
                .accessibilityLabel(settings.l("播放器。按确认键打开控制。", "Playback. Press Select for controls."))
            if playback.controlsVisible { controls }
        }
        .background(.black).ignoresSafeArea()
        .onPlayPauseCommand { playback.togglePause() }
        .onExitCommand { playback.back() }
        .onAppear { screenFocused = true }
        .onChange(of: playback.controlsVisible) { _, visible in screenFocused = !visible; controlFocused = visible }
        .onChange(of: settings.value.soundVolume) { _, volume in sound.setVolume(volume, gain: playback.timeline.audioGain(at: playback.now)) }
        .sheet(isPresented: $showingMixer, onDismiss: { playback.choosingOptions = false; playback.interaction() }) { SoundMixerView() }
        .sheet(isPresented: $savingRoutine, onDismiss: { playback.choosingOptions = false; playback.interaction() }) { SaveRoutineView() }
        .onChange(of: playback.timeline.expired(at: playback.now)) { _, expired in
            if expired { showingMixer = false; savingRoutine = false }
        }
    }

    @ViewBuilder private var screen: some View {
        if playback.effectiveScene == .black {
            Color.black
        } else {
            ZStack {
                if playback.effectiveScene == .gallery {
                    GalleryArtwork(address: currentPhoto)
                } else {
                    ZStack {
                        SceneArtwork(kind: playback.effectiveScene)
                        if playback.effectiveScene != .clock && !reduceMotion {
                            VideoScene(kind: playback.effectiveScene, paused: playback.paused || scenePhase != .active, speed: settings.value.speed)
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                    .id(playback.effectiveScene).transition(.opacity)
                    .animation(.easeInOut(duration: reduceMotion ? 0 : 1.5), value: playback.effectiveScene)
                }
                if playback.effectiveScene == .clock || settings.value.showClock {
                    FloatingClock(date: playback.now, language: settings.language, format24: settings.value.clock24Hour, large: playback.effectiveScene == .clock)
                }
                Color.black.opacity(1 - settings.value.brightness * playback.timeline.audioGain(at: playback.now) * playback.timeline.pictureGain(at: playback.now)).allowsHitTesting(false)
            }
        }
    }

    private var currentPhoto: String? {
        let photos = settings.value.photos
        guard !photos.isEmpty else { return nil }
        let index = Int(playback.visualElapsed / Double(settings.value.photoSeconds)) % photos.count
        return photos[index]
    }

    private var controls: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(playback.effectiveScene.title(settings.language)).font(.title2)
                        Text(statusText).font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text(settings.l("10 秒后隐藏", "Hides after 10 seconds")).font(.caption).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 20) {
                    QuietButton(title: settings.l("上一幕", "Previous"), symbol: "backward.end.fill", id: "player-previous") { playback.step(forward: false) }.focused($controlFocused)
                    QuietButton(title: playback.paused ? settings.l("继续", "Resume") : settings.l("暂停画面", "Pause visuals"), symbol: playback.paused ? "play.fill" : "pause.fill", id: "player-pause") { playback.togglePause() }
                    QuietButton(title: settings.l("下一幕", "Next"), symbol: "forward.end.fill", id: "player-next") { playback.step(forward: true) }
                    QuietButton(title: playback.effectiveScene == .black ? settings.l("打开画面", "Picture on") : settings.l("关闭画面", "Picture off"), symbol: playback.effectiveScene == .black ? "tv" : "moon.zzz.fill", id: "player-black") { playback.toggleVisuals() }
                        .disabled(playback.timeline.expired(at: playback.now) || settings.value.isNight(at: playback.now))
                    QuietButton(title: settings.l("隐藏", "Hide"), symbol: "chevron.down", id: "hide-controls") { playback.controlsVisible = false }
                    QuietButton(title: settings.l("退出", "Exit"), symbol: "xmark", id: "exit-player") { playback.stop() }
                }
                HStack(spacing: 24) {
                    ChoicePicker(title: sound.layers.count > 1 ? settings.l("切换为单声景", "Switch to one sound") : settings.l("搭配声景", "Soundscape"), selection: Binding(get: { sound.selected }, set: { playback.selectSound($0) }),
                                 options: [(nil, settings.l("静音", "Silent"))] + SoundKind.available.map { (Optional($0), $0.title(settings.language)) })
                        .frame(width: 600).accessibilityIdentifier("player-sound")
                        .disabled(playback.timeline.expired(at: playback.now))
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $settings.value.soundVolume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .frame(width: 440).accessibilityIdentifier("player-volume")
                    if let selected = sound.selected {
                        HStack(spacing: 8) {
                            Image(systemName: selected.symbol).accessibilityHidden(true)
                            Text(sound.title(settings.language)).lineLimit(2).accessibilityIdentifier("player-sound-status")
                        }.font(.caption).foregroundStyle(Palette.accent)
                    }
                    Spacer()
                }.focusSection()
                if let error = sound.error { Text(error).font(.caption).foregroundStyle(.orange) }
                HStack(spacing: 24) {
                    ChoicePicker(title: settings.l("睡眠定时", "Sleep timer"), selection: Binding(get: { settings.value.sleepMinutes }, set: { playback.setSleep($0) }),
                                 options: [(0, settings.l("关闭", "Off"))] + [5, 10, 15, 20, 30, 60, 90, 120].map { ($0, settings.l("\($0) 分钟", "\($0) min")) })
                        .frame(width: 480).accessibilityIdentifier("player-timer")
                    QuietButton(title: settings.value.favorites.contains(playback.scene) ? settings.l("移除收藏", "Unsave") : settings.l("收藏", "Save"), symbol: "heart", id: "player-favorite") { settings.toggleFavorite(playback.scene); playback.interaction() }
                    if sound.selected != nil {
                        QuietButton(title: settings.l("停止声景", "Stop sound"), symbol: "speaker.slash", id: "player-stop-sound") { sound.stop(); playback.interaction() }
                    }
                }
                HStack(spacing: 24) {
                    ChoicePicker(title: settings.l("自动黑屏", "Picture timer"), selection: Binding(
                        get: { playback.timeline.pictureDeadline == nil ? 0 : settings.value.pictureOffMinutes ?? 0 },
                        set: { playback.setPictureOff($0) }),
                        options: [(0, settings.l("关闭", "Off"))] + [1, 5, 10, 15, 30].map { ($0, settings.l("\($0) 分钟后", "After \($0) min")) })
                        .frame(width: 480).accessibilityIdentifier("player-picture-timer")
                        .disabled(playback.timeline.expired(at: playback.now))
                    QuietButton(title: settings.l("混合声景", "Mix sounds"), symbol: "slider.horizontal.3", id: "player-mixer") { showingMixer = true }
                        .disabled(playback.timeline.expired(at: playback.now))
                    QuietButton(title: settings.l("保存方案", "Save routine"), symbol: "bookmark", id: "save-routine") { savingRoutine = true }
                }.focusSection()
            }.padding(40).background(Color(red: 0.035, green: 0.035, blue: 0.05), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.06)))
                .padding(64)
        }
        .focusSection()
    }

    private var statusText: String {
        if playback.timeline.expired(at: playback.now) { return settings.l("睡眠定时已结束 · 保持纯黑", "Sleep timer ended · staying dark") }
        if settings.value.isNight(at: playback.now) { return settings.l("夜间规则生效 · 保持纯黑", "Night schedule active · staying dark") }
        if let seconds = playback.secondsRemaining { return settings.l("睡眠定时剩余 \(seconds / 60) 分 \(seconds % 60) 秒", "Sleep timer: \(seconds / 60)m \(seconds % 60)s") }
        if let seconds = playback.pictureSecondsRemaining { return settings.l("\(seconds / 60) 分 \(seconds % 60) 秒后关闭画面，声音继续", "Picture off in \(seconds / 60)m \(seconds % 60)s; sound continues") }
        return settings.l("音乐由原播放器控制 · 返回键先隐藏控制", "Your music stays with its player · Back hides controls first")
    }
}

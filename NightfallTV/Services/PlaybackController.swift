import UIKit
import Combine
import AVFoundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var meditation: MeditationSession?
    private let speech = AVSpeechSynthesizer()
    private var lastMeditationCue: Int?
    @Published var mediaMissing = false
    @Published private(set) var isPlaying = false
    @Published private(set) var scene: SceneKind = .aurora
    @Published private(set) var paused = false
    @Published private(set) var visualsHidden = false
    @Published var controlsVisible = false
    var choosingOptions = false
    @Published private(set) var now = Date()
    @Published private(set) var timeline = PlaybackTimeline(now: Date())
    private var lastInteraction = Date()
    private var ticker: AnyCancellable?
    private var active = true
    private var finishedSleep = false
    let settings: SettingsStore
    let sound: SoundPlayer

    var effectiveScene: SceneKind {
        visualsHidden || timeline.expired(at: now) || settings.value.isNight(at: now) ? .black : scene
    }
    var visualElapsed: Double { timeline.elapsed(at: now) }
    var secondsRemaining: Int? { timeline.deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } }
    var pictureSecondsRemaining: Int? { timeline.pictureDeadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } }

    /// 创建音频会话控制器，维护睡眠定时与黑屏聆听控制层。
    init(settings: SettingsStore, sound: SoundPlayer) {
        self.settings = settings
        self.sound = sound
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.tick(date) }
    }

    /// 用户主动启动带画面的音频会话，停止声音会结束会话，不支持独立静音景色播放。
    func start(_ selected: SceneKind, layers: [SoundLayer]? = nil) {
        guard selected != .clock, selected != .gallery, selected.isAvailable else { mediaMissing = true; return }
        let fallback = selected.suggestedSound.flatMap { $0.isAvailable ? $0 : nil } ?? .rain
        let mix = layers ?? (sound.layers.isEmpty ? [SoundLayer(sound: fallback)] : sound.layers)
        sound.playMix(mix, volume: settings.value.soundVolume)
        sound.setPaused(false)
        guard sound.isPlaying else { return }
        meditation = nil
        speech.stopSpeaking(at: .immediate)
        now = Date()
        scene = selected
        settings.value.lastScene = selected
        timeline = PlaybackTimeline(now: now, sleepMinutes: settings.value.sleepMinutes, pictureOffMinutes: settings.value.pictureOffMinutes ?? 0)
        paused = false
        visualsHidden = false
        finishedSleep = false
        controlsVisible = effectiveScene != .black
        choosingOptions = false
        isPlaying = true
        updateIdleTimer()
    }

    /// 以指定录音开始会话，避免先播默认声景再切换的短暂错音。
    func startWithSound(_ selected: SceneKind, sound selectedSound: SoundKind) {
        guard selected.isAvailable, selectedSound.isAvailable else { mediaMissing = true; return }
        start(selected, layers: [SoundLayer(sound: selectedSound)])
    }

    /// 设备已安装的系统语音决定提示是否可用；不请求麦克风，也不录制语音。
    var meditationVoiceAvailable: Bool { meditationVoice != nil }

    /// 按实际语言选择系统语音，缺失时不以其他语言假装提供提示。
    private var meditationVoice: AVSpeechSynthesisVoice? {
        let codes: [AppLanguage: String] = [.zhHans: "zh-CN", .zhHant: "zh-TW", .en: "en-US", .ja: "ja-JP", .ko: "ko-KR", .fr: "fr-FR", .de: "de-DE", .es: "es-ES", .it: "it-IT", .pt: "pt-BR", .ru: "ru-RU", .ar: "ar-SA", .hi: "hi-IN"]
        return codes[settings.language.resolved].flatMap(AVSpeechSynthesisVoice.init(language:))
    }

    /// 用户确认后开始带呼吸节奏的音频练习；有效练习计时独立于普通睡眠定时。
    func startMeditation(minutes: Int, rhythm: BreathingRhythm, sound selected: SoundKind, voice: Bool = false) {
        startWithSound(selected.visualScene, sound: selected)
        guard isPlaying else { return }
        timeline.setSleep(minutes: 0, now: now)
        meditation = MeditationSession(minutes: minutes, rhythm: rhythm, voiceEnabled: voice && meditationVoiceAvailable)
        lastMeditationCue = nil
        controlsVisible = effectiveScene != .black
        announceMeditationPhase(force: true)
    }

    /// 主动切换节奏语音；关闭、暂停、退出或切后台时立即停止讲话。
    func toggleMeditationVoice() {
        guard meditation?.finished == false, meditationVoiceAvailable else { return }
        meditation?.voiceEnabled.toggle()
        speech.stopSpeaking(at: .immediate)
        announceMeditationPhase(force: true)
        interaction()
    }

    /// 只在新呼吸阶段播一次系统语音，使用本应用音频会话，不排队堆积过期指令。
    private func announceMeditationPhase(force: Bool = false) {
        guard active, !paused, let session = meditation, !session.finished, session.voiceEnabled,
              let voice = meditationVoice else { return }
        let elapsed = timeline.elapsed(at: now)
        let cue = session.cueIndex(elapsed: elapsed)
        guard force || cue != lastMeditationCue else { return }
        lastMeditationCue = cue
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: session.inhaling(elapsed: elapsed) ? settings.l("吸气", "Breathe in") : settings.l("呼气", "Breathe out"))
        utterance.voice = voice
        utterance.rate = 0.4
        utterance.volume = Float(settings.value.soundVolume * min(1, Double(session.remaining(elapsed: elapsed)) / 10))
        speech.usesApplicationAudioSession = true
        speech.speak(utterance)
    }

    /// 只有已选择声音才能关闭画面；没有独立黑屏入口，也不代替系统屏保。
    func startDarkListening() {
        guard !sound.layers.isEmpty else { return }
        if isPlaying { blackNow() } else { start(.black) }
        updateIdleTimer()
    }

    /// 在当前会话更换或停止声景，不重置画面、暂停状态和睡眠截止时间。
    func selectSound(_ selected: SoundKind?) {
        interaction()
        guard let selected else { stop(); return }
        guard !timeline.expired(at: Date()) else { return }
        sound.play(selected, volume: settings.value.soundVolume * timeline.audioGain(at: Date()))
        sound.setPaused(paused)
    }

    /// 保留当前画面和倒计时，仅切换画面可见性；直接黑屏启动可从所选声景恢复对应画面。
    func toggleVisuals() {
        guard !timeline.expired(at: Date()), !settings.value.isNight(at: Date()) else { return }
        if scene == .black {
            scene = sound.selected?.visualScene ?? .aurora
            visualsHidden = false
        } else { visualsHidden.toggle() }
        timeline.setPictureOff(minutes: 0, now: Date())
        controlsVisible = effectiveScene != .black
        interaction()
    }

    /// 回到浏览界面并恢复系统闲置行为，结束当前睡眠会话。
    func stop() {
        isPlaying = false
        meditation = nil
        speech.stopSpeaking(at: .immediate)
        paused = false
        controlsVisible = false
        choosingOptions = false
        timeline.setSleep(minutes: 0, now: Date())
        timeline.setPictureOff(minutes: 0, now: Date())
        sound.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// 记录操作并显示低亮度控制层。
    func showControls() { interaction(); controlsVisible = true }

    /// 返回键优先隐藏控制层，再退出播放器，保留系统 Home 按钮行为。
    func back() {
        if controlsVisible { controlsVisible = false }
        else { stop() }
        interaction()
    }

    /// 同时暂停音频与背景预览，遥控器播放键恢复全部声层，睡眠计时仍按真实时间前进。
    func togglePause() {
        now = Date()
        timeline.togglePause(now: now)
        paused.toggle()
        sound.setPaused(paused)
        if paused { speech.stopSpeaking(at: .immediate) } else { announceMeditationPhase(force: true) }
        interaction()
        updateIdleTimer()
    }

    /// 在同一音频会话切换已下载背景，保留混音和睡眠计时，取消本次关闭画面计时。
    func changeBackground(_ selected: SceneKind) {
        guard isPlaying, !sound.layers.isEmpty, !selected.isPlayerMode, selected.isAvailable else { return }
        scene = selected
        visualsHidden = false
        timeline.setPictureOff(minutes: 0, now: Date())
        controlsVisible = true
        interaction()
    }

    /// 立即隐藏画面，保留声音、倒计时及原场景，稍后可恢复。
    func blackNow() { visualsHidden = true; controlsVisible = false; interaction() }

    /// 重设或取消当前睡眠计时，同时保存下次默认值。
    func setSleep(_ minutes: Int) {
        settings.value.sleepMinutes = minutes
        timeline.setSleep(minutes: minutes, now: Date())
        finishedSleep = false
        interaction()
    }

    /// 设置独立自动黑屏计时，保留声音与睡眠截止时间。
    func setPictureOff(_ minutes: Int) {
        settings.value.pictureOffMinutes = minutes
        timeline.setPictureOff(minutes: minutes, now: Date())
        interaction()
    }

    /// 将当前画面、混音和睡前参数存为个人方案，保存本身不会启动任何声音。
    func saveRoutine(named name: String) -> String? {
        settings.addRoutine(SavedRoutine(name: name, scene: scene, pictureOff: visualsHidden,
                                        layers: sound.layers, volume: settings.value.soundVolume,
                                        brightness: settings.value.brightness, sleepMinutes: settings.value.sleepMinutes,
                                        pictureOffMinutes: timeline.pictureDeadline == nil ? 0 : settings.value.pictureOffMinutes ?? 0))
    }

    /// 用户明确选择个人方案后恢复所有参数，定时从本次启动计算；夜间规则仍生效。
    func startRoutine(_ routine: SavedRoutine, black: Bool = false) {
        var safe = routine
        safe.normalize()
        guard safe.scene.isAvailable, safe.layers.allSatisfy({ $0.sound.isAvailable }) else { mediaMissing = true; return }
        settings.value.soundVolume = safe.volume
        settings.value.brightness = safe.brightness
        settings.value.sleepMinutes = safe.sleepMinutes
        settings.value.pictureOffMinutes = safe.pictureOffMinutes
        start(safe.scene, layers: safe.layers)
        visualsHidden = safe.pictureOff || black
        controlsVisible = effectiveScene != .black
    }

    /// 播放中混音选择保留会话时限，结束后的计时不能通过混音重新发声。
    func toggleSoundLayer(_ kind: SoundKind) {
        guard !isPlaying || !timeline.expired(at: Date()) else { return }
        sound.toggleLayer(kind, volume: settings.value.soundVolume, gain: isPlaying ? timeline.audioGain(at: Date()) : 1)
        sound.setPaused(paused)
        if isPlaying && sound.layers.isEmpty { stop() }
        interaction()
    }

    /// 记录播放控制操作，仅用于自动隐藏控制栏。
    func interaction() { lastInteraction = Date() }

    /// 前后台切换时释放系统闲置锁，停止本应用声景并保留黑屏会话。
    func setActive(_ value: Bool) {
        active = value
        updateIdleTimer()
        if value { tick(Date()) }
        else { speech.stopSpeaking(at: .immediate); sound.stop(); controlsVisible = false; choosingOptions = false }
    }

    /// 仅在前台实际播放媒体时保持亮屏；静音黑屏、暂停或定时结束交还系统闲置行为。
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = active && isPlaying && !timeline.expired(at: now) && sound.isPlaying
    }

    /// 每秒推进控制状态；到期时静默纯黑并停止本应用声音。
    private func tick(_ date: Date) {
        now = date
        defer { updateIdleTimer() }
        guard active, isPlaying else { return }
        let gain = meditation.map { min(1, Double($0.remaining(elapsed: timeline.elapsed(at: date))) / 10) } ?? timeline.audioGain(at: date)
        sound.setVolume(settings.value.soundVolume, gain: gain)
        if controlsVisible && !choosingOptions && date.timeIntervalSince(lastInteraction) >= 10 { controlsVisible = false }
        if var session = meditation {
            let remaining = session.remaining(elapsed: timeline.elapsed(at: date))
            if remaining == 0 {
                if !session.finished {
                    session.finished = true
                    meditation = session
                    speech.stopSpeaking(at: .immediate)
                    sound.stop()
                }
            } else {
                announceMeditationPhase()
                if sound.layers.isEmpty { stop() }
            }
            if timeline.pictureExpired(at: date) && !choosingOptions {
                visualsHidden = true
                controlsVisible = false
                timeline.setPictureOff(minutes: 0, now: date)
            }
            return
        }
        if timeline.expired(at: date) {
            if !finishedSleep {
                sound.stop()
                controlsVisible = false
                finishedSleep = true
            }
            return
        }
        if timeline.pictureExpired(at: date) && !choosingOptions {
            visualsHidden = true
            controlsVisible = false
            timeline.setPictureOff(minutes: 0, now: date)
        }
        // 中断、停止全部混音或解码失败时结束会话，不能留下无声的独立景色播放器。
        if sound.layers.isEmpty { stop() }
    }
}

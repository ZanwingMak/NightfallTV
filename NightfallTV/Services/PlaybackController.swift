import UIKit
import Combine

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var scene: SceneKind = .aurora
    @Published private(set) var paused = false
    @Published var controlsVisible = false
    @Published private(set) var now = Date()
    @Published private(set) var timeline = PlaybackTimeline(now: Date())
    @Published private(set) var playlist: [SceneKind] = []
    private var lastRotation: TimeInterval = 0
    private var lastInteraction = Date()
    private var homeInteraction = Date()
    private var ticker: AnyCancellable?
    private var active = true
    private var finishedSleep = false
    let settings: SettingsStore
    let sound: SoundPlayer

    var effectiveScene: SceneKind {
        timeline.expired(at: now) || settings.value.isNight(at: now) ? .black : scene
    }
    var visualElapsed: Double { timeline.elapsed(at: now) }
    var secondsRemaining: Int? { timeline.deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } }

    /// 创建控制器，并定期维护定时、自动隐藏与轮播状态。
    init(settings: SettingsStore, sound: SoundPlayer) {
        self.settings = settings
        self.sound = sound
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.tick(date) }
    }

    /// 启动屏保或收藏播放列表，始终先隐藏操作界面。
    func start(_ selected: SceneKind, playlist: [SceneKind] = []) {
        now = Date()
        scene = selected
        settings.value.lastScene = selected
        self.playlist = playlist
        timeline = PlaybackTimeline(now: now, sleepMinutes: settings.value.sleepMinutes)
        paused = false
        finishedSleep = false
        lastRotation = 0
        controlsVisible = false
        isPlaying = true
        UIApplication.shared.isIdleTimerDisabled = active
    }

    /// 回到浏览界面并恢复系统闲置行为，结束当前睡眠会话。
    func stop() {
        isPlaying = false
        controlsVisible = false
        timeline.setSleep(minutes: 0, now: Date())
        sound.setVolume(settings.value.soundVolume)
        UIApplication.shared.isIdleTimerDisabled = false
        homeInteraction = Date()
    }

    /// 记录操作并显示低亮度控制层。
    func showControls() { interaction(); controlsVisible = true }

    /// 返回键优先隐藏控制层，再离开屏保，保持遥控器行为可预测。
    func back() {
        if controlsVisible { controlsVisible = false }
        else { stop() }
        interaction()
    }

    /// 暂停动画和轮播，睡眠倒计时仍按真实时间前进。
    func togglePause() { timeline.togglePause(now: Date()); paused.toggle(); interaction() }

    /// 遥控器手动切换场景；纯黑模式不显示自动提示。
    func step(forward: Bool) {
        guard !timeline.expired(at: Date()), !settings.value.isNight(at: Date()) else { return }
        let scenes = playlist.isEmpty ? SceneKind.allCases : playlist
        guard let index = scenes.firstIndex(of: scene), !scenes.isEmpty else { return }
        scene = scenes[(index + (forward ? 1 : scenes.count - 1)) % scenes.count]
        settings.value.lastScene = scene
        lastRotation = timeline.elapsed(at: Date())
        interaction()
    }

    /// 将当前会话立即转入纯黑，并结束轮播。
    func blackNow() { scene = .black; playlist = []; controlsVisible = false; interaction() }

    /// 重设或取消当前睡眠计时，同时保存下次默认值。
    func setSleep(_ minutes: Int) {
        settings.value.sleepMinutes = minutes
        timeline.setSleep(minutes: minutes, now: Date())
        finishedSleep = false
        interaction()
    }

    /// 记录用户操作供自动隐藏与库内闲置判断。
    func interaction() { lastInteraction = Date(); homeInteraction = Date() }

    /// 前后台切换时释放系统闲置锁，停止本应用声景并保留黑屏会话。
    func setActive(_ value: Bool) {
        active = value
        UIApplication.shared.isIdleTimerDisabled = value && isPlaying
        if value { tick(Date()); homeInteraction = Date() }
        else { sound.stop(); controlsVisible = false }
    }

    /// 检查库内闲置启动，仅由支持自动播放的浏览页面调用。
    func checkIdle() {
        let seconds = settings.value.idleSeconds
        if active && !isPlaying && seconds > 0 && now.timeIntervalSince(homeInteraction) >= Double(seconds) {
            start(settings.value.lastScene)
        }
    }

    /// 每秒推进控制状态；到期时静默纯黑并停止本应用声音。
    private func tick(_ date: Date) {
        now = date
        guard active, isPlaying else { return }
        sound.setVolume(settings.value.soundVolume, gain: timeline.audioGain(at: date))
        if controlsVisible && date.timeIntervalSince(lastInteraction) >= 10 { controlsVisible = false }
        if timeline.expired(at: date) {
            if !finishedSleep {
                sound.stop()
                controlsVisible = false
                finishedSleep = true
            }
            return
        }
        let elapsed = timeline.elapsed(at: date)
        if !paused && !settings.value.isNight(at: date) && !playlist.isEmpty && elapsed - lastRotation >= Double(settings.value.rotationSeconds) {
            if let next = PlaybackTimeline.next(in: playlist, current: scene, shuffle: settings.value.shuffle) { scene = next }
            lastRotation = elapsed
        }
    }
}

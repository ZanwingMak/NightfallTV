import AVFoundation
import Combine

@MainActor
final class SoundPlayer: ObservableObject {
    @Published private(set) var selected: SoundKind?
    @Published private(set) var error: String?
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?

    /// 监听音频中断；中断后不自动发声，避免睡眠时意外恢复。
    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.stop() }
        }
    }

    /// 释放通知监听，不保留过期的声音服务引用。
    deinit { if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) } }

    /// 用户主动选择时才激活可混音的环境音频，不压低其他音乐音量。
    func play(_ sound: SoundKind, volume: Double) {
        stop()
        error = nil
        do {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = -1
            next.volume = Float(volume)
            next.prepareToPlay()
            guard next.play() else { throw CocoaError(.fileReadUnknown) }
            player = next
            selected = sound
        } catch {
            self.error = "声音暂时无法播放 / Sound unavailable"
            stop()
        }
    }

    /// 停止本应用声音并释放音频会话；不会控制其他播放器。
    func stop() {
        let hadPlayer = player != nil || selected != nil
        player?.stop()
        player = nil
        selected = nil
        if hadPlayer { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    /// 根据睡眠计时的淡出比例调整本应用音量。
    func setVolume(_ volume: Double, gain: Double = 1) { player?.volume = Float(min(1, max(0, volume * gain))) }
}

import AVFoundation
import Combine

@MainActor
final class SoundPlayer: ObservableObject {
    @Published private(set) var layers: [SoundLayer] = []
    @Published private(set) var error: String?
    private var players: [SoundKind: AVAudioPlayer] = [:]
    private var masterVolume = 0.25
    private var sleepGain = 1.0
    private var interruptionObserver: NSObjectProtocol?
    var selected: SoundKind? { layers.first?.sound }
    var isPlaying: Bool { !players.isEmpty && players.values.allSatisfy(\.isPlaying) }
    var playingSounds: [SoundKind] { layers.filter { players[$0.sound]?.isPlaying == true }.map(\.sound) }

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
        playMix([SoundLayer(sound: sound)], volume: volume)
    }

    /// 替换混音组合，只重建需要的新播放器；保留共有声音的播放位置。
    func playMix(_ requested: [SoundLayer], volume: Double, gain: Double = 1) {
        let nextLayers = SoundLayer.normalized(requested)
        guard !nextLayers.isEmpty else { stop(); return }
        error = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            if players.isEmpty { try session.setActive(true) }
            var newPlayers: [SoundKind: AVAudioPlayer] = [:]
            for layer in nextLayers where players[layer.sound] == nil {
                guard let url = Bundle.main.url(forResource: layer.sound.rawValue, withExtension: "m4a") else { throw CocoaError(.fileNoSuchFile) }
                let next = try AVAudioPlayer(contentsOf: url)
                next.numberOfLoops = -1
                next.volume = 0
                next.prepareToPlay()
                newPlayers[layer.sound] = next
            }
            for (kind, player) in players where !nextLayers.contains(where: { $0.sound == kind }) {
                player.stop()
                players.removeValue(forKey: kind)
            }
            for (kind, player) in newPlayers {
                players[kind] = player
                guard player.play() else { throw CocoaError(.fileReadUnknown) }
            }
            layers = nextLayers
            masterVolume = Self.clamp(volume)
            sleepGain = Self.clamp(gain)
            applyVolumes(fadeDuration: 0.5)
        } catch {
            self.error = "声音暂时无法播放 / Sound unavailable"
            stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// 添加或移除一层，调整组合时不重启其他录音；最多同时播放三层。
    func toggleLayer(_ kind: SoundKind, volume: Double, gain: Double = 1) {
        if layers.contains(where: { $0.sound == kind }) { playMix(layers.filter { $0.sound != kind }, volume: volume, gain: gain) }
        else if layers.count < 3 { playMix(layers + [SoundLayer(sound: kind)], volume: volume, gain: gain) }
    }

    /// 调整单层相对音量，不重启音频或睡眠计时。
    func setLevel(_ level: Double, for kind: SoundKind) {
        guard let index = layers.firstIndex(where: { $0.sound == kind }) else { return }
        layers[index].level = level.isFinite ? min(1, max(0.1, level)) : 1
        applyVolumes(fadeDuration: 0.25)
    }

    /// 返回当前组合名称，用真实的所有选中层显示播放状态。
    func title(_ english: Bool) -> String { layers.map { $0.sound.title(english) }.joined(separator: " + ") }

    /// 读取录音的实际播放位置，用于确认切换混音时持续播放而非重新启动。
    func playbackTime(for kind: SoundKind) -> TimeInterval? { players[kind]?.currentTime }

    /// 停止本应用声音并释放音频会话；不会控制其他播放器。
    func stop() {
        let hadPlayer = !players.isEmpty
        players.values.forEach { $0.stop() }
        players = [:]
        layers = []
        if hadPlayer { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    /// 根据睡眠计时的淡出比例调整本应用音量。
    func setVolume(_ volume: Double, gain: Double = 1) {
        masterVolume = Self.clamp(volume)
        sleepGain = Self.clamp(gain)
        applyVolumes(fadeDuration: 0.25)
    }

    /// 各层增益总和最多等于主音量，混合多层也保持明确的峰值余量。
    static func mixGains(_ layers: [SoundLayer], volume: Double, gain: Double = 1) -> [SoundKind: Double] {
        let safe = SoundLayer.normalized(layers)
        let scale = clamp(volume) * clamp(gain) / max(1, safe.reduce(0) { $0 + $1.level })
        return Dictionary(uniqueKeysWithValues: safe.map { ($0.sound, $0.level * scale) })
    }

    /// 平滑应用最新组合音量，自动淡出同时影响所有声景层。
    private func applyVolumes(fadeDuration: TimeInterval) {
        for (kind, level) in Self.mixGains(layers, volume: masterVolume, gain: sleepGain) {
            players[kind]?.setVolume(Float(level), fadeDuration: fadeDuration)
        }
    }

    /// 无效或非有限增益按零处理，避免异常音量穿透。
    private static func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
}

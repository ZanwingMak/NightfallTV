import Foundation

enum BreathingRhythm: String, CaseIterable, Identifiable {
    case gentle, balanced
    var id: String { rawValue }
    var inhale: Double { 4 }
    var exhale: Double { self == .gentle ? 6 : 4 }
    var cycle: Double { inhale + exhale }
}

struct MeditationSession {
    let minutes: Int
    let rhythm: BreathingRhythm
    var voiceEnabled: Bool
    var finished = false
    var duration: Double { Double(minutes) * 60 }

    /// 只接受界面提供的练习时长，异常值回退十分钟。
    init(minutes: Int, rhythm: BreathingRhythm, voiceEnabled: Bool = false) {
        self.minutes = [5, 10, 20].contains(minutes) ? minutes : 10
        self.rhythm = rhythm
        self.voiceEnabled = voiceEnabled
    }

    /// 剩余时间按有效练习时长计算；暂停期间不会减少。
    func remaining(elapsed: Double) -> Int { max(0, Int(ceil(duration - elapsed))) }

    /// 使用同一时间源计算呼吸阶段，前四秒吸气，其余时间呼气，不要求屏息。
    func inhaling(elapsed: Double) -> Bool { max(0, elapsed).truncatingRemainder(dividingBy: rhythm.cycle) < rhythm.inhale }

    /// 阶段标识同时包含轮次，确保语音每个阶段只播一次。
    func cueIndex(elapsed: Double) -> Int { Int(max(0, elapsed) / rhythm.cycle) * 2 + (inhaling(elapsed: elapsed) ? 0 : 1) }

    /// 返回当前阶段的剩余秒数，界面和语音始终采用相同节奏。
    func phaseRemaining(elapsed: Double) -> Int {
        let position = max(0, elapsed).truncatingRemainder(dividingBy: rhythm.cycle)
        return Int(ceil((position < rhythm.inhale ? rhythm.inhale : rhythm.cycle) - position))
    }

    /// 用余弦曲线平滑缩放引导圆环，吸气展开、呼气收拢。
    func circleScale(elapsed: Double) -> Double {
        let position = max(0, elapsed).truncatingRemainder(dividingBy: rhythm.cycle)
        let fraction = position < rhythm.inhale ? position / rhythm.inhale : 1 - (position - rhythm.inhale) / rhythm.exhale
        return 0.68 + 0.32 * (1 - cos(fraction * .pi)) / 2
    }
}

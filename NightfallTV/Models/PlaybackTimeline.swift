import Foundation

struct PlaybackTimeline {
    private(set) var startedAt: Date
    private(set) var pausedAt: Date?
    private(set) var pausedDuration: TimeInterval = 0
    private(set) var deadline: Date?

    /// 新建会话；睡眠定时使用墙钟时间，不随动画暂停。
    init(now: Date, sleepMinutes: Int = 0) {
        startedAt = now
        setSleep(minutes: sleepMinutes, now: now)
    }

    /// 计算排除暂停时长的动画和轮播时间。
    func elapsed(at now: Date) -> TimeInterval {
        max(0, (pausedAt ?? now).timeIntervalSince(startedAt) - pausedDuration)
    }

    /// 暂停或继续视觉时间轴。
    mutating func togglePause(now: Date) {
        if let pause = pausedAt { pausedDuration += max(0, now.timeIntervalSince(pause)); pausedAt = nil }
        else { pausedAt = now }
    }

    /// 重新设置定时器；零值代表取消。
    mutating func setSleep(minutes: Int, now: Date) {
        deadline = minutes > 0 ? now.addingTimeInterval(Double(minutes) * 60) : nil
    }

    /// 判断睡眠定时是否到期。
    func expired(at now: Date) -> Bool { deadline.map { now >= $0 } ?? false }

    /// 返回最后三十秒的声音淡出比例。
    func audioGain(at now: Date) -> Double {
        guard let deadline else { return 1 }
        return min(1, max(0, deadline.timeIntervalSince(now) / 30))
    }

    /// 为顺序或随机轮播选出下一项，保证随机多项时不重复当前项。
    static func next(in scenes: [SceneKind], current: SceneKind, shuffle: Bool) -> SceneKind? {
        guard !scenes.isEmpty else { return nil }
        if scenes.count == 1 { return scenes[0] }
        if shuffle { return scenes.filter { $0 != current }.randomElement() }
        guard let index = scenes.firstIndex(of: current) else { return scenes[0] }
        return scenes[(index + 1) % scenes.count]
    }
}

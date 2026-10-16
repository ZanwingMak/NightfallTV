import XCTest
@testable import NightfallTV

@MainActor
final class RoutineTests: XCTestCase {
    /// 为方案测试建立独立本地存储，避免修改用户设置。
    private func store() -> (SettingsStore, UserDefaults, String) {
        let domain = "NightfallTV.routines.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        return (SettingsStore(defaults: defaults), defaults, domain)
    }

    /// 三层混音的实际播放器同时播放；修改组合和音量不重启保留的录音。
    func testActualMixContinuityAndStop() async throws {
        let sound = SoundPlayer()
        defer { sound.stop() }
        sound.play(.rain, volume: 0.25)
        try await Task.sleep(nanoseconds: 200_000_000)
        let position = try XCTUnwrap(sound.playbackTime(for: .rain))
        sound.toggleLayer(.ocean, volume: 0.25)
        sound.toggleLayer(.wind, volume: 0.25)
        XCTAssertEqual(sound.playingSounds, [.rain, .ocean, .wind])
        XCTAssertTrue(sound.isPlaying)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(sound.playbackTime(for: .rain)), position)
        sound.toggleLayer(.birds, volume: 0.25)
        XCTAssertEqual(sound.layers.count, 3)
        sound.setLevel(0.25, for: .rain)
        XCTAssertEqual(sound.layers.first?.level, 0.25)
        sound.toggleLayer(.ocean, volume: 0.25)
        XCTAssertEqual(sound.playingSounds, [.rain, .wind])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(sound.playbackTime(for: .rain)), position)
        sound.stop()
        XCTAssertTrue(sound.playingSounds.isEmpty)
        XCTAssertFalse(sound.isPlaying)
    }

    /// 所有混合增益之和不超过主音量，淡出作用于全部层，异常输入不会穿透。
    func testMixHeadroomAndNormalization() {
        let input = [SoundLayer(sound: .rain, level: 1), SoundLayer(sound: .ocean, level: 0.5), SoundLayer(sound: .wind, level: 0.25)]
        let gains = SoundPlayer.mixGains(input, volume: 0.8, gain: 0.5)
        XCTAssertEqual(gains.values.reduce(0, +), 0.4, accuracy: 0.000001)
        XCTAssertEqual(gains[.rain]!, 2 * gains[.ocean]!, accuracy: 0.000001)
        XCTAssertTrue(SoundPlayer.mixGains(input, volume: .nan).values.allSatisfy { $0 == 0 })
        let invalid = [SoundLayer(sound: .rain, level: .infinity), SoundLayer(sound: .rain), SoundLayer(sound: .fire, level: -1), SoundLayer(sound: .birds), SoundLayer(sound: .ocean)]
        XCTAssertEqual(SoundLayer.normalized(invalid).map(\.sound), [.rain, .fire, .birds])
        XCTAssertEqual(SoundLayer.normalized(invalid)[1].level, 0.1)
    }

    /// 旧版偏好缺少新字段时保留已有收藏、照片和音量，而非重置用户设置。
    func testLegacyPreferencesAndSavedRoutinePersistence() throws {
        let (_, defaults, domain) = store()
        defer { defaults.removePersistentDomain(forName: domain) }
        var old = Preferences()
        old.favorites = [.stars, .snow]
        old.soundVolume = 0.5
        old.photos = ["https://example.com/photo.png"]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "pictureOffMinutes")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "nightfall.preferences.v1")
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.value.favorites, old.favorites)
        XCTAssertEqual(settings.value.photos, old.photos)
        XCTAssertEqual(settings.value.soundVolume, 0.5)
        XCTAssertEqual(settings.value.pictureOffMinutes, 0)
        let routine = SavedRoutine(name: "  雨夜  ", scene: .clouds, pictureOff: false, layers: [SoundLayer(sound: .rain), SoundLayer(sound: .ocean, level: 0.5)], volume: 0.25, brightness: 0.2, sleepMinutes: 60, pictureOffMinutes: 5)
        XCTAssertNil(settings.addRoutine(routine))
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.routines.first?.name, "雨夜")
        XCTAssertEqual(restored.routines.first?.layers, routine.layers)
        XCTAssertEqual(restored.routines.first?.pictureOffMinutes, 5)
        restored.removeRoutine(routine.id)
        XCTAssertTrue(SettingsStore(defaults: defaults).routines.isEmpty)
        XCTAssertNil(restored.addRoutine(routine))
        restored.reset()
        XCTAssertTrue(SettingsStore(defaults: defaults).routines.isEmpty)
    }

    /// 方案数量和空名称受限，损坏的方案存储不会影响正常偏好恢复。
    func testRoutineLimitsAndCorruptStorage() {
        let (settings, defaults, domain) = store()
        defer { defaults.removePersistentDomain(forName: domain) }
        var routine = SavedRoutine(name: "", scene: .ocean, pictureOff: false, layers: [], volume: 0.25, brightness: 0.8, sleepMinutes: 0, pictureOffMinutes: 0)
        XCTAssertNotNil(settings.addRoutine(routine))
        for index in 0..<12 {
            routine.id = UUID().uuidString
            routine.name = "方案 \(index)"
            XCTAssertNil(settings.addRoutine(routine))
        }
        XCTAssertNotNil(settings.addRoutine(routine))
        defaults.set(Data("broken".utf8), forKey: "nightfall.routines.v1")
        XCTAssertTrue(SettingsStore(defaults: defaults).routines.isEmpty)
        XCTAssertEqual(SettingsStore(defaults: defaults).value, settings.value)
    }

    /// 保存不会停止或重启混音；播放个人方案恢复参数，并保持夜间安全边界。
    func testRoutineRestoresSessionAndNightRule() {
        let (settings, defaults, domain) = store()
        defer { defaults.removePersistentDomain(forName: domain) }
        let sound = SoundPlayer()
        defer { sound.stop() }
        let playback = PlaybackController(settings: settings, sound: sound)
        playback.startWithSound(.clouds, sound: .rain)
        playback.toggleSoundLayer(.ocean)
        playback.setSleep(60)
        playback.setPictureOff(5)
        let deadline = playback.timeline.deadline
        XCTAssertNil(playback.saveRoutine(named: "海边雨夜"))
        XCTAssertEqual(playback.timeline.deadline, deadline)
        XCTAssertTrue(sound.isPlaying)
        playback.stop()
        playback.startRoutine(settings.routines[0], black: true)
        XCTAssertEqual(playback.scene, .clouds)
        XCTAssertEqual(playback.effectiveScene, .black)
        XCTAssertEqual(sound.playingSounds, [.rain, .ocean])
        XCTAssertLessThanOrEqual(abs(playback.secondsRemaining! - 3600), 1)
        XCTAssertLessThanOrEqual(abs(playback.pictureSecondsRemaining! - 300), 1)
        playback.toggleVisuals()
        XCTAssertNil(playback.timeline.pictureDeadline)
        XCTAssertEqual(playback.effectiveScene, .clouds)
        settings.value.nightEnabled = true
        settings.value.nightStartHour = 0
        settings.value.nightEndHour = 0
        playback.startRoutine(settings.routines[0])
        playback.toggleVisuals()
        XCTAssertEqual(playback.effectiveScene, .black)
        playback.setActive(false)
        XCTAssertTrue(sound.playingSounds.isEmpty)
    }

    /// 独立黑屏计时按真实时间运行，不延长睡眠倒计时，也不影响其淡出比例。
    func testIndependentPictureTimer() {
        let now = Date(timeIntervalSince1970: 1000)
        var timeline = PlaybackTimeline(now: now, sleepMinutes: 30, pictureOffMinutes: 1)
        timeline.togglePause(now: now.addingTimeInterval(10))
        XCTAssertFalse(timeline.pictureExpired(at: now.addingTimeInterval(59)))
        XCTAssertTrue(timeline.pictureExpired(at: now.addingTimeInterval(60)))
        XCTAssertEqual(timeline.pictureGain(at: now.addingTimeInterval(55)), 0.5)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(55)), 1)
        XCTAssertFalse(timeline.expired(at: now.addingTimeInterval(60)))
        let deadline = timeline.deadline
        timeline.setPictureOff(minutes: 0, now: now.addingTimeInterval(60))
        XCTAssertNil(timeline.pictureDeadline)
        XCTAssertEqual(timeline.deadline, deadline)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(1785)), 0.5)
    }
}

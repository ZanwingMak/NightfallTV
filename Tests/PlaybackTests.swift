import XCTest
@testable import NightfallTV

@MainActor
final class PlaybackTests: XCTestCase {
    /// 隔离测试偏好，并使用真实声音服务验证播放会话而非模拟声音状态。
    private func controller() -> (PlaybackController, UserDefaults, String) {
        let domain = "NightfallTV.playback.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        let settings = SettingsStore(defaults: defaults)
        let sound = SoundPlayer()
        return (PlaybackController(settings: settings, sound: sound), defaults, domain)
    }

    /// 关画面和恢复保留音频暂停、原声景与截止时间，停止声音必须结束会话。
    func testPictureTogglePreservesSessionAndPlayingAudio() {
        let (playback, defaults, domain) = controller()
        defer { playback.sound.stop(); defaults.removePersistentDomain(forName: domain) }
        playback.settings.value.sleepMinutes = 30
        playback.start(.ocean)
        playback.selectSound(.ocean)
        playback.togglePause()
        let deadline = playback.timeline.deadline
        XCTAssertFalse(playback.sound.isPlaying)
        playback.toggleVisuals()
        XCTAssertEqual(playback.effectiveScene, .black)
        XCTAssertEqual(playback.scene, .ocean)
        XCTAssertTrue(playback.paused)
        XCTAssertEqual(playback.timeline.deadline, deadline)
        XCTAssertFalse(playback.sound.isPlaying)
        playback.toggleVisuals()
        XCTAssertEqual(playback.effectiveScene, .ocean)
        XCTAssertEqual(playback.sound.selected, .ocean)
        XCTAssertEqual(playback.timeline.deadline, deadline)
        playback.selectSound(.birds)
        XCTAssertFalse(playback.sound.isPlaying)
        playback.togglePause()
        XCTAssertTrue(playback.sound.isPlaying)
        XCTAssertEqual(playback.timeline.deadline, deadline)
        playback.selectSound(nil)
        XCTAssertFalse(playback.sound.isPlaying)
        XCTAssertFalse(playback.isPlaying)
    }

    /// 所有播放均有明确音频，纯音频恢复对应背景，后台停止声音。
    func testBlackSoundRestoresSuggestedPictureAndBackgroundStopsAudio() {
        let (playback, defaults, domain) = controller()
        defer { playback.sound.stop(); defaults.removePersistentDomain(forName: domain) }
        playback.start(.waterfall)
        XCTAssertEqual(playback.sound.selected, .waterfall)
        playback.startWithSound(.black, sound: .crickets)
        XCTAssertTrue(playback.sound.isPlaying)
        playback.toggleVisuals()
        XCTAssertEqual(playback.effectiveScene, .stars)
        playback.blackNow()
        XCTAssertEqual(playback.effectiveScene, .black)
        playback.toggleVisuals()
        XCTAssertEqual(playback.effectiveScene, .stars)
        playback.setActive(false)
        XCTAssertFalse(playback.sound.isPlaying)
        XCTAssertNil(playback.sound.selected)
    }

    /// 手动画面恢复不能越过夜间规则；新场景能在已有偏好中持久化且保留旧收藏。
    func testNightRuleAndExpandedCatalogPersistence() {
        let (playback, defaults, domain) = controller()
        defer { playback.sound.stop(); defaults.removePersistentDomain(forName: domain) }
        playback.settings.value.nightEnabled = true
        playback.settings.value.nightStartHour = 0
        playback.settings.value.nightEndHour = 0
        playback.start(.snow)
        playback.toggleVisuals()
        XCTAssertEqual(playback.scene, .snow)
        XCTAssertEqual(playback.effectiveScene, .black)
        playback.settings.value.nightEnabled = false
        XCTAssertEqual(playback.effectiveScene, .snow)
        playback.settings.toggleFavorite(.clouds)
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.value.lastScene, .snow)
        XCTAssertTrue(restored.value.favorites.contains(.clouds))
        XCTAssertTrue(restored.value.favorites.contains(.aurora))
    }
}

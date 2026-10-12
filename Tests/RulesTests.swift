import XCTest
import AVFoundation
@testable import NightfallTV

final class RulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)

    /// 验证所有屏保和全部离线声音都有独立的标识与文案。
    func testCatalogIsComplete() {
        XCTAssertEqual(SceneKind.allCases.count, 17)
        XCTAssertEqual(SoundKind.allCases.count, 14)
        for scene in SceneKind.allCases {
            XCTAssertFalse(scene.title(false).isEmpty)
            XCTAssertFalse(scene.title(true).isEmpty)
            XCTAssertFalse(scene.subtitle(false).isEmpty)
            XCTAssertFalse(scene.symbol.isEmpty)
        }
    }

    /// 夜间跨午夜时正确包含开始边界并排除结束边界。
    func testOvernightWindow() {
        var preferences = Preferences()
        preferences.nightEnabled = true
        let calendar = Calendar(identifier: .gregorian)
        for (hour, expected) in [(22, false), (23, true), (0, true), (6, true), (7, false), (12, false)] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour))!
            XCTAssertEqual(preferences.isNight(at: date, calendar: calendar), expected, "hour \(hour)")
        }
    }

    /// 验证白天窗口、全天窗口与关闭规则。
    func testDaytimeAndAllDayWindow() {
        var preferences = Preferences()
        preferences.nightEnabled = true
        preferences.nightStartHour = 8
        preferences.nightEndHour = 17
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 10))!
        XCTAssertTrue(preferences.isNight(at: date, calendar: calendar))
        preferences.nightEndHour = 8
        XCTAssertTrue(preferences.isNight(at: date, calendar: calendar))
        preferences.nightEnabled = false
        XCTAssertFalse(preferences.isNight(at: date, calendar: calendar))
    }

    /// 暂停只冻结视觉时间，睡眠定时仍会到期。
    func testPauseDoesNotDelaySleep() {
        var timeline = PlaybackTimeline(now: now, sleepMinutes: 15)
        timeline.togglePause(now: now.addingTimeInterval(10))
        XCTAssertEqual(timeline.elapsed(at: now.addingTimeInterval(50)), 10)
        XCTAssertTrue(timeline.expired(at: now.addingTimeInterval(900)))
        timeline.togglePause(now: now.addingTimeInterval(100))
        XCTAssertEqual(timeline.elapsed(at: now.addingTimeInterval(110)), 20)
    }

    /// 验证重设、取消和最后三十秒渐弱的边界值。
    func testSleepResetCancelAndFade() {
        var timeline = PlaybackTimeline(now: now, sleepMinutes: 15)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(870)), 1)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(885)), 0.5)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(900)), 0)
        XCTAssertFalse(timeline.expired(at: now.addingTimeInterval(899)))
        timeline.setSleep(minutes: 30, now: now.addingTimeInterval(1000))
        XCTAssertFalse(timeline.expired(at: now.addingTimeInterval(1001)))
        timeline.setSleep(minutes: 0, now: now)
        XCTAssertNil(timeline.deadline)
        XCTAssertEqual(timeline.audioGain(at: now.addingTimeInterval(10000)), 1)
    }

    /// 轮播处理空列表、单个场景和顺序循环。
    func testRotationEdgeCases() {
        XCTAssertNil(PlaybackTimeline.next(in: [], current: .black, shuffle: true))
        XCTAssertEqual(PlaybackTimeline.next(in: [.aurora], current: .aurora, shuffle: true), .aurora)
        XCTAssertEqual(PlaybackTimeline.next(in: [.aurora, .ocean], current: .aurora, shuffle: false), .ocean)
        XCTAssertEqual(PlaybackTimeline.next(in: [.aurora, .ocean], current: .ocean, shuffle: false), .aurora)
        XCTAssertEqual(PlaybackTimeline.next(in: [.aurora, .ocean], current: .black, shuffle: false), .aurora)
        for _ in 0..<100 { XCTAssertNotEqual(PlaybackTimeline.next(in: [.aurora, .ocean, .stars], current: .aurora, shuffle: true), .aurora) }
    }

    /// 图片地址拒绝明文协议、内嵌密码和空主机。
    func testPhotoValidation() {
        XCTAssertTrue(Preferences.validPhotoURL("https://example.com/photo.jpg?width=1920"))
        for bad in ["http://example.com/a.jpg", "file:///a.jpg", "https:///", "https://user:secret@example.com/a.jpg", "javascript:alert(1)", "https://exa mple.com/a.jpg", ""] {
            XCTAssertFalse(Preferences.validPhotoURL(bad), bad)
        }
    }

    /// 损坏及越界偏好被收敛为可用参数。
    func testNormalization() {
        var preferences = Preferences()
        preferences.brightness = -5
        preferences.speed = .infinity
        preferences.soundVolume = 5
        preferences.rotationSeconds = -1
        preferences.photoSeconds = 1
        preferences.sleepMinutes = -1
        preferences.nightStartHour = 42
        preferences.nightEndHour = -1
        preferences.favorites = [.black, .black, .ocean]
        preferences.photos = ["http://example.com/a", "https://example.com/a", "https://example.com/a"]
        preferences.normalize()
        XCTAssertEqual(preferences.brightness, 0.05)
        XCTAssertEqual(preferences.speed, 0.5)
        XCTAssertEqual(preferences.soundVolume, 1)
        XCTAssertEqual(preferences.rotationSeconds, 300)
        XCTAssertEqual(preferences.photoSeconds, 30)
        XCTAssertEqual(preferences.sleepMinutes, 0)
        XCTAssertEqual(preferences.nightStartHour, 23)
        XCTAssertEqual(preferences.nightEndHour, 0)
        XCTAssertEqual(preferences.favorites, [.black, .ocean])
        XCTAssertEqual(preferences.photos, ["https://example.com/a"])
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    /// 使用独立测试存储验证收藏、照片、重复校验和持久恢复。
    func testRoundTripAndPhotoErrors() {
        let domain = "NightfallTV.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = SettingsStore(defaults: defaults)
        store.toggleFavorite(.black)
        store.value.launchBlack = true
        XCTAssertNil(store.addPhoto(" https://example.com/a.png "))
        XCTAssertNotNil(store.addPhoto("https://example.com/a.png"))
        XCTAssertNotNil(store.addPhoto("http://example.com/a.png"))
        let restored = SettingsStore(defaults: defaults)
        XCTAssertTrue(restored.value.favorites.contains(.black))
        XCTAssertTrue(restored.value.launchBlack)
        XCTAssertEqual(restored.value.photos, ["https://example.com/a.png"])
        restored.reset()
        XCTAssertEqual(SettingsStore(defaults: defaults).value, Preferences())
    }

    /// 损坏 JSON 不会造成应用启动崩溃。
    func testCorruptPreferencesRecover() {
        let domain = "NightfallTV.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(Data("broken".utf8), forKey: "nightfall.preferences.v1")
        XCTAssertEqual(SettingsStore(defaults: defaults).value, Preferences())
    }

    /// 画廊数量限制生效，且移除后允许继续添加。
    func testGalleryLimit() {
        let domain = "NightfallTV.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = SettingsStore(defaults: defaults)
        for index in 0..<30 { XCTAssertNil(store.addPhoto("https://example.com/\(index).png")) }
        XCTAssertNotNil(store.addPhoto("https://example.com/31.png"))
        store.value.photos.removeFirst()
        XCTAssertNil(store.addPhoto("https://example.com/31.png"))
    }

    /// 音频资源实际存在且能被播放器解码，保证离线声景不是空入口。
    func testBundledAudioDecodes() throws {
        for sound in SoundKind.allCases.filter({ !$0.isDownload }) {
            let url = try XCTUnwrap(Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 25)
            XCTAssertEqual(player.numberOfChannels, 2)
        }
    }

    /// 对公开的项目截图执行真实 HTTPS 下载，验证解码、缓存及非图片响应拒绝。
    func testRemotePhotosAndCache() async throws {
        let root = "https://raw.githubusercontent.com/ZanwingMak/NightfallTV/main/"
        let address = root + "docs/screens/dunes.png"
        let image = try await PhotoLoader.shared.load(address)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 3840)
        let cached = try await PhotoLoader.shared.load(address)
        XCTAssertTrue(image === cached)
        do {
            _ = try await PhotoLoader.shared.load(root + "README.md")
            XCTFail("Non-image response must be rejected")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }
}

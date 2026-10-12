import XCTest
import CryptoKit
import AVFoundation
@testable import NightfallTV

final class LocalizationTests: XCTestCase {
    /// 全部界面键在十二份非英语翻译中齐全，插值占位符不丢失。
    func testTranslationsAreCompleteAndPreserveParameters() {
        XCTAssertGreaterThan(Localizer.translations.count, 230)
        let languages = AppLanguage.allCases.filter { $0 != .system && $0 != .en }
        for (key, translations) in Localizer.translations {
            for language in languages {
                let value = translations[language.rawValue] ?? ""
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key): \(language)")
                for number in 0...2 { XCTAssertEqual(value.contains("{\(number)}"), key.contains("{\(number)}"), "\(key): \(language)") }
            }
        }
        XCTAssertEqual(Localizer.text("15 minutes", language: .ja), "15 分")
        XCTAssertEqual(Localizer.text("15 minutes", language: .ar), "15 دقيقة")
        XCTAssertEqual(AppLanguage.match("zh-TW"), .zhHant)
        XCTAssertEqual(AppLanguage.match("pt-PT"), .pt)
        XCTAssertEqual(AppLanguage.match("xx-XX"), .en)
        XCTAssertTrue(AppLanguage.ar.isRTL)
        XCTAssertFalse(AppLanguage.ja.isRTL)
    }

    /// 旧布尔偏好可迁移，手动语言选项跨重启保存。
    @MainActor func testLanguagePersistenceAndLegacyPreference() throws {
        let domain = "NightfallTV.language.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        var legacy = Preferences()
        legacy.english = true
        defaults.set(try JSONEncoder().encode(legacy), forKey: "nightfall.preferences.v1")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.language, .en)
        store.setLanguage(.ar)
        XCTAssertEqual(SettingsStore(defaults: defaults).language, .ar)
        XCTAssertEqual(SettingsStore(defaults: defaults).value.languageCode, "ar")
    }
}

@MainActor
final class DownloadTests: XCTestCase {
    /// 高清媒体只存在于下载清单中，包里仅有海报和署名。
    func testOptionalMediaAreNotBundled() {
        XCTAssertEqual(DownloadAsset.all.count, 8)
        XCTAssertEqual(Set(DownloadAsset.all.compactMap(\.scene)), Set(SceneKind.allCases.filter(\.isDownload)))
        XCTAssertEqual(Set(DownloadAsset.all.compactMap(\.sound)), Set(SoundKind.allCases.filter(\.isDownload)))
        for asset in DownloadAsset.all {
            XCTAssertEqual(asset.url.host, "github.com")
            XCTAssertEqual(asset.url.scheme, "https")
            XCTAssertGreaterThan(asset.bytes, 100_000)
            XCTAssertEqual(asset.sha256.count, 64)
            XCTAssertEqual(asset.licenseURL.scheme, "https")
            XCTAssertEqual(asset.sourceURL.scheme, "https")
            XCTAssertFalse(asset.author.isEmpty)
            XCTAssertFalse(asset.changes.isEmpty)
            XCTAssertNil(Bundle.main.url(forResource: asset.id, withExtension: asset.scene == nil ? "m4a" : "mp4"))
        }
    }

    /// 拒绝截断文件与同大小不同内容，不把错误下载标记为可播放。
    func testIntegrityRejectsTruncationAndWrongData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("A real media fixture".utf8)
        try data.write(to: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertTrue(try MediaTransfer.verify(url, bytes: Int64(data.count), sha256: hash))
        XCTAssertFalse(try MediaTransfer.verify(url, bytes: Int64(data.count + 1), sha256: hash))
        XCTAssertFalse(try MediaTransfer.verify(url, bytes: Int64(data.count), sha256: String(repeating: "0", count: 64)))
    }

    /// 真实公开资源下载后解码，再删除，验证视频4K和音频48kHz立体声及离线状态恢复。
    func testPublishedDownloadDecodesAndRemovalResetsAvailability() async throws {
        let store = DownloadStore.shared
        for id in ["valley", "parkbirds"] {
            let asset = try XCTUnwrap(DownloadAsset.all.first { $0.id == id })
            if store.ready.contains(id) { store.remove(asset) }
            defer { if DownloadStore.fileURL(asset) != nil { store.remove(asset) } }
            store.download(asset)
            for _ in 0..<900 {
                if store.ready.contains(id) || store.errors.contains(id) { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            XCTAssertFalse(store.errors.contains(id))
            let url = try XCTUnwrap(DownloadStore.fileURL(asset))
            XCTAssertTrue(try MediaTransfer.verify(url, bytes: asset.bytes, sha256: asset.sha256))
            if asset.scene != nil {
                let movie = AVURLAsset(url: url)
                let audioTracks = try await movie.loadTracks(withMediaType: .audio)
                XCTAssertTrue(audioTracks.isEmpty)
                let videoTracks = try await movie.loadTracks(withMediaType: .video)
                let video = try XCTUnwrap(videoTracks.first)
                let size = try await video.load(.naturalSize)
                XCTAssertEqual(size.width, 3840)
                XCTAssertEqual(size.height, 2160)
            } else {
                let audio = try AVAudioFile(forReading: url)
                XCTAssertEqual(audio.processingFormat.sampleRate, 48000)
                XCTAssertEqual(audio.processingFormat.channelCount, 2)
            }
            store.remove(asset)
            XCTAssertFalse(store.ready.contains(id))
            XCTAssertNil(DownloadStore.fileURL(asset))
        }
    }

    /// 取消下载后不可被迟到的完成回调重新登记，也不保留临时资源。
    func testCancelledDownloadStaysUnavailable() async throws {
        let asset = try XCTUnwrap(DownloadAsset.all.first { $0.id == "mountains" })
        let store = DownloadStore.shared
        if store.ready.contains(asset.id) { store.remove(asset) }
        store.download(asset)
        store.cancel(asset)
        try await Task.sleep(for: .seconds(1))
        XCTAssertNil(store.progress[asset.id])
        XCTAssertNil(DownloadStore.fileURL(asset))
        XCTAssertFalse(store.errors.contains(asset.id))
    }
}

import XCTest
import AVFoundation
@testable import NightfallTV

@MainActor
final class MediaTests: XCTestCase {
    /// 实际解码全部实拍资源，确保高清视频、预览与署名齐全且没有音轨。
    func testFilmedMediaAreCompleteAndSilent() async throws {
        let expected = Set(SceneKind.allCases.filter { $0.category == .nature })
        XCTAssertEqual(Set(VideoCredit.all.map(\.scene)), expected)
        XCTAssertEqual(VideoCredit.all.count, expected.count)
        for credit in VideoCredit.all {
            XCTAssertTrue(credit.sourceURL.hasPrefix("https://"))
            XCTAssertTrue(credit.licenseURL.hasPrefix("https://"))
            XCTAssertFalse(credit.creator.isEmpty)
            XCTAssertFalse(credit.changes.isEmpty)
            XCTAssertNotNil(UIImage(named: "\(credit.scene.rawValue)-poster"))
            let url = try XCTUnwrap(Bundle.main.url(forResource: credit.scene.rawValue, withExtension: "mp4"))
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            XCTAssertGreaterThan(duration.seconds, 8)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            XCTAssertTrue(audio.isEmpty, "\(credit.scene): must never interrupt music with source audio")
            let video = try await asset.loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(video.first)
            let size = try await track.load(.naturalSize)
            XCTAssertGreaterThanOrEqual(size.height, 720)
            XCTAssertLessThanOrEqual(size.width, 1920)
        }
        let coordinator = VideoScene.Coordinator()
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient)
        XCTAssertTrue(AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers))
        XCTAssertTrue(coordinator.player.isMuted)
        coordinator.stop()
    }
}

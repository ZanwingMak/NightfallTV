import XCTest
import UIKit

final class ScreenTests: XCTestCase {
    /// 用真实遥控器方向键移动焦点后选择目标，tvOS 不使用鼠标点击。
    private func activate(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let matchingCells = app.cells.containing(.button, identifier: identifier)
        let target = matchingCells.firstMatch.exists ? matchingCells.firstMatch : app.buttons[identifier].firstMatch
        guard target.waitForExistence(timeout: 10) else { XCTFail("Missing \(identifier)", file: file, line: line); return }
        for _ in 0..<30 {
            if target.hasFocus || target.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.exists {
                XCUIRemote.shared.press(.select)
                return
            }
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            guard focused.exists else { XCUIRemote.shared.press(.down); continue }
            let source = focused.frame, destination = target.frame
            let direction: XCUIRemote.Button
            if destination.minY > source.maxY { direction = .down }
            else if destination.maxY < source.minY { direction = .up }
            else { direction = destination.midX > source.midX ? .right : .left }
            XCUIRemote.shared.press(direction)
        }
        XCTFail("Unable to focus \(identifier): \(app.debugDescription)", file: file, line: line)
    }

    /// 建立可重复的独立启动状态，避免测试读取用户偏好。
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
        return app
    }

    /// 保存回归截图到测试结果包，供人工视觉检查。
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 逐像素确认纯黑画面，不允许任何可见 RGB 分量。
    private func assertBlack(file: StaticString = #filePath, line: UInt = #line) throws {
        let cgImage = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage, file: file, line: line)
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), file: file, line: line)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var lit = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] != 0 || pixels[index + 1] != 0 || pixels[index + 2] != 0 { lit += 1 }
        }
        XCTAssertEqual(lit, 0, "\(lit) pixels are not absolute black", file: file, line: line)
    }

    /// 完整通过首屏按钮进入黑屏，验证控制层显示、隐藏与返回。
    func testBlackScreenRemoteFlow() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["quick-black"].waitForExistence(timeout: 15))
        capture("01-library")
        activate("quick-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 10))
        try assertBlack()
        capture("02-absolute-black")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5))
        capture("03-player-controls")
        XCUIRemote.shared.press(.menu)
        XCTAssertFalse(app.buttons["exit-player"].exists)
        try assertBlack()
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["quick-black"].waitForExistence(timeout: 5))
    }

    /// 启动即黑屏没有先显示首页，并能通过确认键退出。
    func testLaunchBlack() throws {
        let app = launch(["--launch-black", "--clock-overlay"])
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 10))
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5))
        activate("exit-player", in: app)
        XCTAssertTrue(app.buttons["quick-black"].waitForExistence(timeout: 5))
    }

    /// 检查所有场景可独立启动，保存每种场景的真实渲染截图。
    func testEverySceneRenders() {
        for scene in ["aurora", "stars", "ocean", "ember", "dunes", "prism", "rain", "clock", "gallery"] {
            let app = launch(["--scene=\(scene)"])
            XCTAssertTrue(app.descendants(matching: .any)["playing-\(scene)"].waitForExistence(timeout: 10), scene)
            capture("scene-\(scene)")
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5), scene)
            app.terminate()
        }
    }

    /// 收藏详情操作和播放列表启动经过实际焦点与选择流程。
    func testFavoritesAndCollection() {
        let app = launch()
        activate("hero-aurora", in: app)
        XCTAssertTrue(app.buttons["favorite-scene"].waitForExistence(timeout: 5))
        activate("favorite-scene", in: app)
        XCUIRemote.shared.press(.menu)
        activate("nav-collection", in: app)
        XCTAssertFalse(app.buttons["scene-aurora"].exists)
        capture("04-collection")
        activate("play-collection", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-stars"].waitForExistence(timeout: 5))
    }

    /// 声景播放、停止、夜间设置和主设置页面均可使用遥控器访问。
    func testSoundAndSettingsPages() {
        let app = launch()
        activate("nav-sounds", in: app)
        XCTAssertTrue(app.buttons["sound-rain"].waitForExistence(timeout: 5))
        capture("05-soundscapes")
        activate("sound-rain", in: app)
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("细雨"))
        activate("stop-sound", in: app)
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("静音"))
        activate("nav-night", in: app)
        XCTAssertTrue(app.buttons["night-black"].waitForExistence(timeout: 5))
        capture("06-night")
        activate("nav-settings", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["brightness"].waitForExistence(timeout: 5))
        capture("07-settings")
        activate("brightness", in: app)
        activate("20%", in: app)
        XCTAssertTrue(app.buttons["brightness"].firstMatch.label.contains("20%"))
    }
}

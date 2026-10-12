import XCTest
import UIKit

final class ScreenTests: XCTestCase {
    /// 首个断言失败时停止该用例，避免后续遥控器输入掩盖最初的问题。
    override func setUp() { super.setUp(); continueAfterFailure = false }
    /// 用真实遥控器方向键移动焦点后选择目标，tvOS 不使用鼠标点击。
    private func activate(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        focus(identifier, in: app, file: file, line: line)
        XCUIRemote.shared.press(.select)
    }

    /// 只移动遥控器焦点，供方向导航回归检查，避免选择操作掩盖焦点死角。
    private func focus(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let matchingCells = app.cells.containing(.button, identifier: identifier)
        let target = matchingCells.firstMatch.exists ? matchingCells.firstMatch : app.buttons[identifier].firstMatch
        // 懒加载网格会移除屏幕外的节点，先用真实方向键寻找上方，再寻找下方内容。
        if !target.exists {
            for direction in [XCUIRemote.Button.up, .down] {
                for _ in 0..<16 {
                    if target.exists { break }
                    XCUIRemote.shared.press(direction)
                }
                if target.exists { break }
            }
        }
        guard target.waitForExistence(timeout: 10) else { XCTFail("Missing \(identifier)", file: file, line: line); return }
        for _ in 0..<30 {
            if target.hasFocus || target.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch.exists {
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

    /// 首排三个卡片都能直接向上进入分类，再向上进入精选按钮和顶部导航。
    func testFirstRowMovesUpToCategories() {
        let app = launch()
        for scene in ["black", "aurora", "stars"] {
            focus("scene-\(scene)", in: app)
            XCTAssertTrue(app.buttons["scene-\(scene)"].hasFocus)
            XCUIRemote.shared.press(.up)
            let categories = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'category-' AND hasFocus == true"))
            XCTAssertTrue(categories.firstMatch.waitForExistence(timeout: 3), "Up from \(scene) must reach a category")
        }
        XCUIRemote.shared.press(.up)
        let hero = app.buttons.matching(NSPredicate(format: "(identifier == 'hero-aurora' OR identifier == 'quick-black') AND hasFocus == true"))
        XCTAssertTrue(hero.firstMatch.waitForExistence(timeout: 3))
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'nav-' AND hasFocus == true")).firstMatch.waitForExistence(timeout: 3))
        capture("14-first-row-up-navigation")
    }

    /// 最后一排仅有一张卡片时，从上一排右侧按一次向下也必须能到达。
    func testLastRowReachableFromRightColumn() {
        let app = launch()
        focus("scene-snow", in: app)
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(app.buttons["scene-clouds"].hasFocus)
        activate("nav-sounds", in: app)
        focus("sound-wind", in: app)
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(app.buttons["sound-waterfall"].hasFocus)
        capture("18-single-card-row-focus")
    }

    /// 全部声景都能切换、停止，首排任意卡片可直接向上进入画面控制。
    func testAllSoundSelectionsAndUpNavigation() throws {
        let app = launch()
        activate("nav-sounds", in: app)
        let names = [("rain", "细雨"), ("ocean", "潮汐"), ("stream", "溪流"), ("fire", "炉火"), ("pink", "粉噪音"), ("brown", "棕噪音"), ("birds", "林间鸟鸣"), ("crickets", "夏夜虫鸣"), ("wind", "风过树叶"), ("waterfall", "瀑布")]
        for (id, name) in names {
            activate("sound-\(id)", in: app)
            XCTAssertTrue(app.staticTexts["sound-status"].label.contains(name))
        }
        for id in ["rain", "ocean", "stream"] {
            focus("sound-\(id)", in: app)
            XCUIRemote.shared.press(.up)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "(identifier == 'sound-picture' OR identifier == 'sound-visual' OR identifier == 'sound-black') AND hasFocus == true")).firstMatch.waitForExistence(timeout: 3))
        }
        capture("15-sound-controls-up-navigation")
        activate("sound-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 5))
        try assertBlack()
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.staticTexts["sound-status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("瀑布"))
        activate("stop-sound", in: app)
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("静音"))
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
    private func litPixelCount(file: StaticString = #filePath, line: UInt = #line) throws -> Int {
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
        return lit
    }

    /// 验证画面完全没有亮像素，避免只依赖可能滞后的可访问性快照。
    private func assertBlack(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try litPixelCount(file: file, line: line), 0, "Pixels must be absolute black", file: file, line: line)
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
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["exit-player"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
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
        for scene in ["aurora", "stars", "ocean", "ember", "dunes", "prism", "rain", "clock", "gallery", "waterfall", "snow", "clouds"] {
            let app = launch(["--scene=\(scene)"])
            XCTAssertTrue(app.descendants(matching: .any)["playing-\(scene)"].waitForExistence(timeout: 10), scene)
            settle(3)
            capture("scene-\(scene)")
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5), scene)
            app.terminate()
        }
    }

    /// 由声景页开画面，再两次切换纯黑和恢复，保持声音并允许播放中更换声景。
    func testSoundPictureToggleAndCustomPairing() throws {
        let app = launch()
        activate("nav-sounds", in: app)
        XCTAssertFalse(app.buttons["sound-visual"].isEnabled)
        activate("sound-birds", in: app)
        activate("sound-picture", in: app)
        activate("云海漫行", in: app)
        activate("sound-visual", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-clouds"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        activate("player-timer", in: app)
        activate("30 分钟", in: app)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("林间鸟鸣"))
        capture("16-sound-picture-controls")
        activate("player-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 5))
        try assertBlack()
        XCUIRemote.shared.press(.up)
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("林间鸟鸣"))
        activate("player-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-clouds"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        activate("player-sound", in: app)
        activate("夏夜虫鸣", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("夏夜虫鸣"))
        activate("player-stop-sound", in: app)
        XCTAssertFalse(app.descendants(matching: .any)["player-sound-status"].firstMatch.exists)
    }

    /// 场景详情的有声入口和睡前快捷方案均经过真实遥控器选择，纯黑快捷方案无亮像素。
    func testAudibleSceneAndBedtimeRoutine() throws {
        let app = launch()
        activate("scene-waterfall", in: app)
        activate("start-scene-sound", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-waterfall"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("瀑布"))
        activate("exit-player", in: app)
        XCTAssertTrue(app.buttons["start-scene-sound"].waitForExistence(timeout: 5))
        settle(1)
        XCUIRemote.shared.press(.menu)
        activate("nav-night", in: app)
        activate("night-rain", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 5))
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("细雨"))
        capture("17-bedtime-routine")
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
    /// 确认真实视频持续运动、遥控器暂停确实冻结像素，且纯黑不会被方向键误亮。
    func testVideoPauseAndRemoteSwitching() throws {
        let app = launch(["--scene=ocean"])
        XCTAssertTrue(app.descendants(matching: .any)["playing-ocean"].waitForExistence(timeout: 10))
        settle(3)
        let moving = XCUIScreen.main.screenshot().pngRepresentation
        settle(2)
        XCTAssertNotEqual(moving, XCUIScreen.main.screenshot().pngRepresentation)
        XCUIRemote.shared.press(.playPause)
        settle(2)
        let frozen = XCUIScreen.main.screenshot().pngRepresentation
        settle(2)
        XCTAssertEqual(frozen, XCUIScreen.main.screenshot().pngRepresentation)
        capture("08-real-video-paused")
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-pause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player-pause"].label.contains("继续"))
        XCUIRemote.shared.press(.menu)
        XCUIRemote.shared.press(.playPause)
        settle(2)
        XCTAssertNotEqual(frozen, XCUIScreen.main.screenshot().pngRepresentation)
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.descendants(matching: .any)["playing-ember"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.left)
        XCTAssertTrue(app.descendants(matching: .any)["playing-ocean"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        activate("player-black", in: app)
        for direction in [XCUIRemote.Button.left, .right, .up, .down, .playPause] { XCUIRemote.shared.press(direction) }
        try assertBlack()
    }

    /// 选择框允许慢慢操作，取消保持原值，结束操作后控制层才开始自动隐藏。
    func testTimerPickerAndControlAutoHide() throws {
        let app = launch(["--launch-black"])
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-timer"].waitForExistence(timeout: 5))
        activate("player-timer", in: app)
        XCTAssertTrue(app.buttons["15 分钟"].waitForExistence(timeout: 5))
        settle(12)
        XCTAssertTrue(app.buttons["15 分钟"].exists, "Picker must remain available while choosing")
        capture("09-sleep-options")
        activate("15 分钟", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["player-timer"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("15 分钟"))
        activate("player-timer", in: app)
        XCTAssertTrue(app.buttons["close-options"].waitForExistence(timeout: 5))
        settle(1)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("15 分钟"))
        settle(1)
        XCTAssertGreaterThan(try litPixelCount(), 0, "Back from picker should keep the controls visible")
        settle(12)
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5))
    }

    /// 混音的三层限制、相对音量、保存、重启恢复和删除均经过实际遥控器流程。
    func testSoundMixAndSavedRoutineLifecycle() {
        let app = launch(["--scene=clouds"])
        XCUIRemote.shared.press(.select)
        activate("player-mixer", in: app)
        activate("mix-rain", in: app)
        activate("mix-ocean", in: app)
        activate("mix-wind", in: app)
        XCTAssertFalse(app.buttons["mix-birds"].isEnabled)
        activate("mix-level-ocean", in: app)
        activate("25%", in: app)
        XCTAssertTrue(app.buttons["mix-level-ocean"].label.contains("25%"))
        settle(12)
        XCTAssertTrue(app.buttons["close-mixer"].exists, "Nested choice must not hide its mixer")
        capture("19-three-layer-mixer")
        activate("close-mixer", in: app)
        XCTAssertTrue(app.staticTexts["player-sound-status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["player-sound-status"].label.contains("潮汐"))
        activate("player-timer", in: app)
        activate("30 分钟", in: app)
        activate("player-picture-timer", in: app)
        activate("5 分钟后", in: app)
        activate("save-routine", in: app)
        activate("confirm-save-routine", in: app)
        activate("exit-player", in: app)
        app.terminate()
        app.launchArguments = []
        app.launch()
        activate("nav-night", in: app)
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'routine-black-'" )).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        capture("20-saved-routine")
        activate(saved.identifier, in: app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        XCTAssertTrue(app.buttons["player-picture-timer"].label.contains("5 分钟后"))
        let status = app.staticTexts["player-sound-status"].label
        for title in ["细雨", "潮汐", "风过树叶"] { XCTAssertTrue(status.contains(title)) }
        activate("exit-player", in: app)
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'routine-remove-'" )).firstMatch
        activate(remove.identifier, in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.right)
        XCTAssertTrue(app.alerts.firstMatch.buttons["移除"].firstMatch.hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertFalse(saved.exists)
    }

    /// 等待真实一分钟验证自动黑屏独立于睡眠计时，恢复后保留混音并取消亮屏截止时间。
    func testAutomaticPictureOffKeepsMixAndSleep() throws {
        let app = launch(["--scene=ocean"])
        XCUIRemote.shared.press(.select)
        activate("player-mixer", in: app)
        activate("mix-rain", in: app)
        activate("mix-ocean", in: app)
        activate("close-mixer", in: app)
        activate("player-timer", in: app)
        activate("30 分钟", in: app)
        activate("player-picture-timer", in: app)
        activate("1 分钟后", in: app)
        activate("hide-controls", in: app)
        XCUIRemote.shared.press(.playPause)
        settle(62)
        try assertBlack()
        XCUIRemote.shared.press(.select)
        let status = app.staticTexts["player-sound-status"].label
        XCTAssertTrue(status.contains("细雨") && status.contains("潮汐"))
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        activate("player-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-ocean"].waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-picture-timer"].label.contains("关闭"))
        capture("21-picture-timer-restored")
    }

    /// 等待播放器实际提交视频帧或定时器推进；不模拟应用内部状态。
    private func settle(_ seconds: TimeInterval) {
        let elapsed = expectation(description: "Rendering interval")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: seconds + 3)
    }

    /// 分类在详情返回后保留，语言选择可取消，授权页可由遥控器关闭。
    func testCategoryReturnLanguageAndCredits() {
        let app = launch()
        activate("category-night", in: app)
        activate("scene-clock", in: app)
        XCTAssertTrue(app.buttons["close-detail"].waitForExistence(timeout: 5))
        activate("close-detail", in: app)
        XCTAssertFalse(app.buttons["scene-aurora"].exists, "Returning should preserve the chosen filter")
        capture("10-night-category")
        activate("nav-settings", in: app)
        activate("language", in: app)
        activate("English", in: app)
        XCTAssertTrue(app.buttons["language"].label.contains("English"))
        settle(1)
        capture("11-english-settings")
        activate("media-credits", in: app)
        XCTAssertTrue(app.buttons["close-credits"].waitForExistence(timeout: 5))
        capture("12-footage-credits")
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["media-credits"].waitForExistence(timeout: 5))
    }

    /// 超过炉火片段完整时长后继续检查帧变化，验证实际循环没有停在末帧。
    func testRealVideoLoopsBeyondItsDuration() {
        let app = launch(["--scene=ember"])
        XCTAssertTrue(app.descendants(matching: .any)["playing-ember"].waitForExistence(timeout: 10))
        settle(24)
        let frame = XCUIScreen.main.screenshot().pngRepresentation
        settle(2)
        XCTAssertNotEqual(frame, XCUIScreen.main.screenshot().pngRepresentation)
        capture("13-real-fire-loop")
    }

}

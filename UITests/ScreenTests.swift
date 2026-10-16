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

    /// 首排任意声景都能向上进入播放设置，首页没有独立视频或照片入口。
    func testFirstRowMovesUpToCategories() {
        let app = launch()
        XCTAssertFalse(app.buttons["nav-explore"].exists)
        XCTAssertFalse(app.buttons["nav-collection"].exists)
        XCTAssertFalse(app.buttons["sound-black"].isEnabled)
        for sound in ["rain", "ocean", "stream"] {
            focus("sound-\(sound)", in: app)
            XCUIRemote.shared.press(.up)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "(identifier == 'sound-picture' OR identifier == 'sound-visual') AND hasFocus == true")).firstMatch.waitForExistence(timeout: 3))
        }
        capture("14-first-row-up-navigation")
    }

    /// 最后一排仅有一张声景卡片时，从上一排右侧仍能用向下键到达。
    func testLastRowReachableFromRightColumn() {
        let app = launch()
        focus("sound-wind", in: app)
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(app.buttons["sound-white"].hasFocus)
        capture("18-single-card-row-focus")
    }

    /// 全部声景都能切换、停止，首排任意卡片可直接向上进入画面控制。
    func testAllSoundSelectionsAndUpNavigation() throws {
        let app = launch()
        activate("nav-sounds", in: app)
        let names = [("rain", "细雨"), ("ocean", "潮汐"), ("stream", "溪流"), ("fire", "炉火"), ("pink", "粉噪音"), ("brown", "棕噪音"), ("birds", "林间鸟鸣"), ("crickets", "夏夜虫鸣"), ("wind", "风过树叶"), ("waterfall", "瀑布"), ("white", "白噪音")]
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
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("静音"))
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
        XCTAssertTrue(app.buttons["sound-black"].waitForExistence(timeout: 15))
        capture("01-sounds")
        activate("sound-rain", in: app)
        activate("sound-black", in: app)
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
        XCTAssertTrue(app.buttons["sound-black"].waitForExistence(timeout: 5))
    }

    /// 已移除启动即黑屏；旧启动参数不能再自动开始会话，仍可手动播放纯音频。
    func testLaunchBlack() throws {
        let app = launch(["--launch-black", "--clock-overlay"])
        XCTAssertTrue(app.buttons["sound-black"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["black-screen"].exists)
        XCTAssertFalse(app.buttons["sound-black"].isEnabled)
        activate("sound-rain", in: app)
        activate("sound-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 10))
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["exit-player"].waitForExistence(timeout: 5))
        activate("exit-player", in: app)
        XCTAssertTrue(app.buttons["sound-black"].waitForExistence(timeout: 5))
    }

    /// 每种可用背景均以实际音频会话启动，控件常驻，不能独立静音播放。
    func testEverySceneRenders() {
        for scene in ["aurora", "stars", "ocean", "ember", "dunes", "prism", "rain", "waterfall", "snow", "clouds"] {
            let app = launch(["--scene=\(scene)"])
            XCTAssertTrue(app.descendants(matching: .any)["playing-\(scene)"].waitForExistence(timeout: 10), scene)
            settle(3)
            capture("scene-\(scene)")
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
        activate("player-sound", in: app)
        activate("夏夜虫鸣", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("夏夜虫鸣"))
        activate("player-stop-sound", in: app)
        XCTAssertTrue(app.staticTexts["sound-status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("静音"))
    }

    /// 声景搭配背景和睡前快捷方案均经过真实遥控器选择，纯音频会话无亮像素。
    func testAudibleSceneAndBedtimeRoutine() throws {
        let app = launch()
        activate("sound-waterfall", in: app)
        activate("sound-visual", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-waterfall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("瀑布"))
        activate("exit-player", in: app)
        XCTAssertTrue(app.buttons["sound-waterfall"].waitForExistence(timeout: 5))
        activate("nav-night", in: app)
        activate("night-rain", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 5))
        try assertBlack()
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        XCTAssertTrue(app.descendants(matching: .any)["player-sound-status"].firstMatch.label.contains("细雨"))
        capture("17-bedtime-routine")
    }

    /// 亮屏时常驻播放器控件，暂停后可继续，停止会结束会话而非留下无声视频。
    func testFavoritesAndCollection() {
        let app = launch()
        activate("sound-ocean", in: app)
        activate("sound-visual", in: app)
        XCTAssertTrue(app.buttons["player-pause"].waitForExistence(timeout: 5))
        settle(12)
        XCTAssertTrue(app.buttons["player-pause"].exists)
        XCTAssertFalse(app.buttons["hide-controls"].exists)
        XCTAssertFalse(app.buttons["player-next"].exists)
        activate("player-pause", in: app)
        XCTAssertTrue(app.buttons["player-pause"].label.contains("继续"))
        activate("player-pause", in: app)
        activate("player-stop-sound", in: app)
        XCTAssertTrue(app.staticTexts["sound-status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sound-status"].label.contains("静音"))
        capture("04-audio-session-stopped")
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
    /// 嵌入式背景随音频暂停或恢复，纯黑不会被方向键误亮。
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
        XCTAssertTrue(app.buttons["player-pause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player-pause"].label.contains("继续"))
        XCUIRemote.shared.press(.playPause)
        settle(2)
        XCTAssertNotEqual(frozen, XCUIScreen.main.screenshot().pngRepresentation)
        activate("player-black", in: app)
        for direction in [XCUIRemote.Button.left, .right, .up, .down, .playPause] { XCUIRemote.shared.press(direction) }
        try assertBlack()
    }

    /// 选择框允许慢慢操作，取消保持原值，结束操作后控制层才开始自动隐藏。
    func testTimerPickerAndControlAutoHide() throws {
        let app = launch(["--scene=ocean"])
        activate("player-black", in: app)
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
        activate("player-mixer", in: app)
        activate("mix-rain", in: app)
        activate("mix-ocean", in: app)
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
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: saved)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed)
    }

    /// 等待真实一分钟验证自动黑屏独立于睡眠计时，恢复后保留混音并取消亮屏截止时间。
    func testAutomaticPictureOffKeepsMixAndSleep() throws {
        let app = launch(["--scene=ocean"])
        activate("player-mixer", in: app)
        activate("mix-rain", in: app)
        activate("close-mixer", in: app)
        activate("player-timer", in: app)
        activate("30 分钟", in: app)
        activate("player-picture-timer", in: app)
        activate("1 分钟后", in: app)
        XCUIRemote.shared.press(.playPause)
        settle(62)
        try assertBlack()
        XCUIRemote.shared.press(.select)
        let status = app.staticTexts["player-sound-status"].label
        XCTAssertTrue(status.contains("细雨") && status.contains("潮汐"))
        XCTAssertTrue(app.buttons["player-timer"].label.contains("30 分钟"))
        activate("player-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-ocean"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player-picture-timer"].label.contains("关闭"))
        capture("21-picture-timer-restored")
    }

    /// 等待播放器实际提交视频帧或定时器推进；不模拟应用内部状态。
    private func settle(_ seconds: TimeInterval) {
        let elapsed = expectation(description: "Rendering interval")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: seconds + 3)
    }

    /// 语言选择可取消，授权页可由遥控器关闭，已移除的时钟不再出现在设置。
    func testCategoryReturnLanguageAndCredits() {
        let app = launch()
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

    /// 通过遥控器下载、取消、播放及删除，确保可选媒体没有隐式自动下载。
    func testOptionalDownloadRemoteControlsAndPlayback() {
        let app = launch()
        activate("sound-rain", in: app)
        activate("nav-settings", in: app)
        activate("open-downloads", in: app)
        XCTAssertTrue(app.buttons["download-valley"].waitForExistence(timeout: 5))
        // 取消及迟到回调由 DownloadTests 确定性验证；真实网络可能在焦点移动前完成，不能要求瞬态取消按钮一直存在。
        activate("download-valley", in: app)
        XCTAssertTrue(app.buttons["play-download-valley"].waitForExistence(timeout: 90))
        capture("25-download-library-ready")
        activate("play-download-valley", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["playing-valley"].waitForExistence(timeout: 10))
        capture("26-downloaded-4k-playback")
        XCUIRemote.shared.press(.menu)
        activate("nav-settings", in: app)
        activate("open-downloads", in: app)
        activate("delete-valley", in: app)
        XCTAssertTrue(app.buttons["download-valley"].waitForExistence(timeout: 5))
        activate("close-downloads", in: app)
        XCTAssertTrue(app.buttons["open-downloads"].waitForExistence(timeout: 5))
    }

    /// 官网和法律页面二维码可用遥控器打开及退出；赞助页不限制免费功能。
    func testWebsiteLegalLinksAndSupportSheet() {
        let app = launch()
        activate("nav-settings", in: app)
        for page in ["home", "privacy", "terms", "support"] {
            activate("site-\(page)", in: app)
            XCTAssertTrue(app.buttons["close-site-link"].waitForExistence(timeout: 5))
            let url = page == "home" ? "https://zanwingmak.github.io/NightfallTV/" : "https://zanwingmak.github.io/NightfallTV/\(page).html"
            XCTAssertTrue(app.staticTexts[url].exists)
            if page == "privacy" { capture("27-privacy-policy-qr") }
            XCUIRemote.shared.press(.menu)
        }
        activate("support-development", in: app)
        XCTAssertTrue(app.buttons["close-support"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tip-status"].exists)
        capture("28-support-development")
        activate("close-support", in: app)
        activate("nav-sounds", in: app)
        activate("sound-rain", in: app)
        activate("sound-black", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["black-screen"].waitForExistence(timeout: 5))
    }

    /// 十三种语言均有可操作导航，阿拉伯语镜像布局仍能通过方向键进入设置并返回。
    func testAllLanguagesHaveWorkingRemoteNavigation() {
        let labels = [("zh-Hans", "设置"), ("zh-Hant", "設定"), ("en", "Settings"), ("ja", "設定"), ("ko", "설정"), ("fr", "Réglages"), ("de", "Einstellungen"), ("es", "Ajustes"), ("it", "Impostazioni"), ("pt-BR", "Configurações"), ("ru", "Настройки"), ("ar", "الإعدادات"), ("hi", "सेटिंग्स")]
        for (code, label) in labels {
            let app = launch(["--language=\(code)"])
            XCTAssertEqual(app.buttons["nav-settings"].label, label)
            activate("nav-settings", in: app)
            activate("language", in: app)
            XCTAssertTrue(app.buttons["English"].waitForExistence(timeout: 5))
            XCUIRemote.shared.press(.menu)
            activate("nav-sounds", in: app)
            if ["de", "ar", "ja", "zh-Hant"].contains(code) { capture("29-language-\(code)") }
            app.terminate()
        }
    }

}

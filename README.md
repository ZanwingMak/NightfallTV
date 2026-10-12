# Nightfall TV · 夜幕

An open-source, native Apple TV screensaver player for a calmer living room and a darker bedroom. Built with SwiftUI and AVFoundation. Free, offline-first, no account, no ads.

原生 Apple TV 屏保播放器：13 种屏保模式，包含 10 个真实拍摄场景、完全黑屏、个人照片画廊、收藏轮播、10 种离线声景、睡眠定时与夜间自动黑屏。免费开源，没有广告或订阅。

![Nightfall TV 实际首页](docs/screens/library.png)

实拍视频、预览与自然录音的作者、来源及许可见[完整素材署名](MEDIA_LICENSES.md)。

| 实拍极光 | 实拍沙漠落日 |
|---|---|
| ![极光](docs/screens/aurora.png) | ![沙漠落日](docs/screens/dunes.png) |

## 功能

- **13 种场景**：纯黑、实拍极光、夜空、海浪、炉火、沙漠落日、树林、雨窗、庭园瀑布、飘雪、云海、漂移时钟、照片画廊。
- **真实景色**：10 个有免费再分发许可的摄影视频，离线静音循环；预览为真实视频帧，最高 1080p，部分为 720p。
- **为卧室设计的全黑**：屏幕输出 RGB 0/0/0，无提示、时钟或焦点边框；启动即黑屏可选。
- **私人收藏**：顺序 / 随机轮播、切换间隔、场景收藏。
- **柔和声景**：雨、海浪、溪流、炉火、林间鸟鸣、夏夜虫鸣、风过树叶、瀑布、粉噪音、棕噪音；八种自然声为实录、两种有色噪音为合成，立体声离线循环，主动选择后才发声。
- **有声屏保与画面开关**：场景详情可带推荐录音启动；声景页可自由搭配画面或纯黑；播放中可换声景、调音量、关画面和恢复，保留睡眠计时。默认不自动发声。
- **睡前快捷方案**：30 分钟细雨、60 分钟棕噪音，一键纯黑入眠。
- **睡眠与夜间**：15–120 分钟定时，结束保持黑屏；画面和本应用声音最后 30 秒一起淡出；自定义跨午夜规则。
- **你的照片**：最多 30 张 HTTPS 图片直链；内存缓存、下载与解码限制；加载失败保持暗色。
- **显示偏好**：亮度、速度、漂移时钟、24 小时制、减少动态效果、中文 / English。

| 声景画面开关 | 新增自然录音 |
|---|---|
| ![声景控制](docs/screens/sound-controls.png) | ![新声景](docs/screens/new-soundscapes.png) |

## 使用

在音乐应用里开始播放 → 返回桌面 → 启动 Nightfall TV → 选择屏保，或「一键黑屏」。主动选择声景会与其他应用音频混音，默认没有声音。不同播放器的后台音乐兼容性需要在真实 Apple TV 验证。

维护者的 TestFlight 内部构建为 **1.1.0（5）**，已完成 Apple 处理并加入 Nightfall Internal。收到邀请的 Apple ID 可在 Apple TV 安装 TestFlight，再接受邀请并安装；目前采用内部测试，不提供公开兑换链接。旧1.0.2（4）已有 Apple TV 4K（第三代，tvOS26.6）安装记录；新版安装、听感、音乐兼容和长时间播放真机验收仍待实际结果，详见回归记录。

[Apple 当前 TestFlight 安装指南](https://beta.itunes.apple.com/)要求 Apple TV 运行 tvOS 18 或以上（应用自身最低 tvOS 17）。邮件邀请需在手机或电脑打开取得兑换码，再到电视上的 TestFlight → Redeem 输入代码；详细安装和配对步骤见[回归文档](docs/回归测试.md#testflight-真机验收)。

| 遥控器 | 操作 |
|---|---|
| 确认 / Select | 播放时显示控制层 |
| 返回 / Back | 先隐藏控制层，再返回播放前的页面 |
| 左 / 右 | 非纯黑模式切换场景 |
| 播放 / 暂停 | 冻结 / 恢复画面及轮播，睡眠定时继续 |
| Home / Siri | 由系统处理 |

## 构建与回归

需要 macOS、Xcode（包含 tvOS SDK）、Apple TV 模拟器；最低 tvOS 17。仓库包含生成好的 Xcode 工程，没有第三方应用依赖。

```bash
open NightfallTV.xcodeproj
xcodebuild -project NightfallTV.xcodeproj -scheme NightfallTV \
  -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

在 Xcode 中选择任意 Apple TV 模拟器，按 `⌘U` 执行测试。命令行测试可将设备 ID 替换为本机 `xcrun simctl list devices available` 的结果：

```bash
xcodebuild -project NightfallTV.xcodeproj -scheme NightfallTV \
  -destination 'platform=tvOS Simulator,id=YOUR_SIMULATOR_ID' \
  CODE_SIGNING_ALLOWED=NO test
```

1.1.0（5）已在 tvOS26.5 的 Apple TV4K 模拟器完成 **18个单元测试＋14个遥控器UI测试，32/32全部通过，0失败、0跳过**（2026-10-12）。[最终应用源码的云端完整回归](https://github.com/ZanwingMak/NightfallTV/actions/runs/38204028253)也已 **32/32通过**（Xcode16.4、tvOS26.1）。测试覆盖自选声景画面、纯黑与恢复、计时不重置、有声屏保、睡前方案及单次方向键跳转，并保存实际界面截图供人工检查。其中照片网络专项访问本仓库的公开截图，离线执行可追加 `-skip-testing:NightfallTVTests/PersistenceTests/testRemotePhotosAndCache`。

如需修改工程配置，安装 XcodeGen 后执行 `xcodegen generate`。实拍视频可用 `python3 scripts/import_media.py` 重新导入（需 FFmpeg，遵守来源网站限流）。自然录音可用 `python3 scripts/import_audio.py` 重新导入，有色噪音可用 `python3 scripts/generate_audio.py` 生成（两者需要 FFmpeg，以及 `python3 -m pip install -r scripts/requirements-audio.txt` 安装的 NumPy）；图标用 `swift scripts/generate_assets.swift` 生成。安装到自己的真机或发布时，请在 Xcode Signing 中替换为自己的 Team 和 Bundle ID；`ExportOptions.plist` 是本项目维护者的发布配置示例，其他开发者需替换对应值。

## 平台边界

这是需手动启动的独立应用，不能成为 tvOS 的系统屏保插件，不能在其他应用上盖黑屏，也不能控制电视背光、关电视或停止外部音乐。LCD 即使输出全黑仍可能有背光；系统音量、Siri 等覆盖层不受应用控制。内置自然景色均为实拍视频；时钟使用暗色背景，私人画廊显示用户照片。

## 文档与开源

- [需求与目标](docs/需求与目标.md)
- [回归计划与实测记录](docs/回归测试.md)
- [隐私说明](PRIVACY.md)
- [问题与建议](https://github.com/ZanwingMak/NightfallTV/issues)

代码、原创图标和有色噪音使用 MIT。实拍视频、原帧预览与自然录音保留原许可，详见[素材来源与许可](MEDIA_LICENSES.md)及应用「设置 → 视听素材来源与授权」。

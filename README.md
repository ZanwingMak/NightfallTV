# Nightfall TV · 夜幕

An open-source, native Apple TV screensaver player for a calmer living room and a darker bedroom. Built with SwiftUI, Canvas and AVFoundation. Free, offline-first, no account, no ads.

原生 Apple TV 屏保播放器：10 种原创场景、完全黑屏、个人照片画廊、收藏轮播、6 种离线声景、睡眠定时与夜间自动黑屏。免费开源，没有广告或订阅。

![Nightfall TV 实际首页](docs/screens/library.png)

| 极光 | 沙丘 |
|---|---|
| ![极光](docs/screens/aurora.png) | ![沙丘](docs/screens/dunes.png) |

## 功能

- **10 种场景**：纯黑、极光、星河、海浪、炉火、沙丘、流光、雨窗、漂移时钟、照片画廊。
- **为卧室设计的全黑**：屏幕输出 RGB 0/0/0，无提示、时钟或焦点边框；启动即黑屏可选。
- **私人收藏**：顺序 / 随机轮播、切换间隔、场景收藏。
- **柔和声景**：雨、海浪、溪流、炉火、粉噪音、棕噪音；本地合成，无缝循环，主动选择后才发声。
- **睡眠与夜间**：15–120 分钟定时，结束保持黑屏；本应用声音最后 30 秒淡出；自定义跨午夜规则。
- **你的照片**：最多 30 张 HTTPS 图片直链；内存缓存、下载与解码限制；加载失败保持暗色。
- **显示偏好**：亮度、速度、漂移时钟、24 小时制、减少动态效果、中文 / English。

## 使用

在音乐应用里开始播放 → 返回桌面 → 启动 Nightfall TV → 选择屏保，或「一键黑屏」。主动选择声景会与其他应用音频混音，默认没有声音。不同播放器的后台音乐兼容性需要在真实 Apple TV 验证。

维护者的 TestFlight 内部构建为 **1.0.0（2）**。收到邀请的 Apple ID 可在 Apple TV 安装 TestFlight，再接受邀请并安装；目前采用内部测试，不提供公开兑换链接。真机安装、音乐和长时间播放验收尚待执行，详见回归记录。

| 遥控器 | 操作 |
|---|---|
| 确认 / Select | 播放时显示控制层 |
| 返回 / Back | 先隐藏控制层，再回到库 |
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

[GitHub 完整回归](https://github.com/ZanwingMak/NightfallTV/actions/runs/38166099652)：13 个单元测试 + 5 个 UI 测试全部通过（2026-10-12）。其中照片网络专项访问本仓库的公开截图，离线执行可追加 `-skip-testing:NightfallTVTests/PersistenceTests/testRemotePhotosAndCache`。

如需修改工程配置，安装 XcodeGen 后执行 `xcodegen generate`。声景与图标可用 `python3 scripts/generate_audio.py`、`swift scripts/generate_assets.swift` 重新生成。安装到自己的真机或发布时，请在 Xcode Signing 中替换为自己的 Team 和 Bundle ID；`ExportOptions.plist` 是本项目维护者的发布配置示例，其他开发者需替换对应值。

## 平台边界

这是需手动启动的独立应用，不能成为 tvOS 的系统屏保插件，不能在其他应用上盖黑屏，也不能控制电视背光、关电视或停止外部音乐。LCD 即使输出全黑仍可能有背光；系统音量、Siri 等覆盖层不受应用控制。内置动态场景为原创生成艺术，不是摄影视频。

## 文档与开源

- [需求与目标](docs/需求与目标.md)
- [回归计划与实测记录](docs/回归测试.md)
- [隐私说明](PRIVACY.md)
- [问题与建议](https://github.com/ZanwingMak/NightfallTV/issues)

MIT License. 场景、图标及声音由本项目原创生成，生成代码包含在仓库内。

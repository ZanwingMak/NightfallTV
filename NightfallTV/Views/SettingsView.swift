import SwiftUI

struct NightView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 56) {
                HStack(alignment: .top, spacing: 72) {
                    VStack(alignment: .leading, spacing: 40) {
                        PageHeading(eyebrow: "GOOD NIGHT, NO GLOW", title: settings.l("只听音乐。\n不见亮光。", "Only the music.\nNone of the glow."), subtitle: settings.l("你的卧室，应该安静一点。", "Your bedroom deserves a softer night."))
                        Image(systemName: "moon.zzz").font(.system(size: 140, weight: .ultraLight)).foregroundStyle(Palette.accent.opacity(0.4)).padding(.vertical, 32)
                        QuietButton(title: settings.l("立即完全黑屏", "Absolute black now"), symbol: "moon.zzz.fill", id: "night-black") { playback.start(.black) }
                        HStack(spacing: 20) {
                            QuietButton(title: settings.l("细雨 · 30 分钟", "Rain · 30 min"), symbol: "cloud.rain.fill", id: "night-rain") { startRoutine(.rain) }
                            QuietButton(title: settings.l("棕噪 · 60 分钟", "Brown · 60 min"), symbol: "waveform.path", id: "night-brown") { startRoutine(.brown) }
                        }.focusSection()
                        Text(settings.l("确认键打开控制，返回键退出。\n电视背光与系统提示由设备控制。", "Select opens controls. Back exits.\nTV backlight and system overlays are controlled by your devices.")).font(.callout).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Form {
                        Section(settings.l("睡眠定时", "Sleep timer")) {
                            ChoicePicker(title: settings.l("进入屏保后", "After starting"), selection: $settings.value.sleepMinutes,
                                         options: [(0, settings.l("不设定时", "No timer"))] + [15, 30, 60, 90, 120].map { ($0, settings.l("\($0) 分钟", "\($0) minutes")) })
                                .accessibilityIdentifier("sleep-minutes")
                            Text(settings.l("到期保持黑屏，最后 30 秒渐弱画面和本应用声景。不会停止其他应用音乐。", "Stays black at the end. Picture and our sounds fade during the last 30 seconds. Other apps' music is not stopped.")).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Section(settings.l("夜间自动黑屏", "Night schedule")) {
                            Toggle(settings.l("开启夜间规则", "Enable schedule"), isOn: $settings.value.nightEnabled).accessibilityIdentifier("night-enabled")
                            ChoicePicker(title: settings.l("从", "From"), selection: $settings.value.nightStartHour, options: (0..<24).map { ($0, String(format: "%02d:00", $0)) })
                            ChoicePicker(title: settings.l("到", "Until"), selection: $settings.value.nightEndHour, options: (0..<24).map { ($0, String(format: "%02d:00", $0)) })
                            Text(settings.l("仅在本应用播放时生效。起止时间相同表示全天黑屏。", "Applies only while playing in this app. Equal start and end times mean all day.")).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Section(settings.l("快速入眠", "A quieter start")) {
                            ChoicePicker(title: settings.l("自动关闭画面", "Automatically go dark"), selection: Binding(
                                get: { settings.value.pictureOffMinutes ?? 0 }, set: { settings.value.pictureOffMinutes = $0 }),
                                options: [(0, settings.l("关闭", "Off"))] + [1, 5, 10, 15, 30].map { ($0, settings.l("\($0) 分钟后", "After \($0) min")) })
                                .accessibilityIdentifier("picture-off-minutes")
                            Text(settings.l("只关闭画面，声景和睡眠计时继续。手动打开画面会取消本次自动黑屏。", "Only the picture turns off. Sounds and sleep timer continue. Manually restoring cancels this picture timer.")).font(.caption).foregroundStyle(Palette.muted)
                            Toggle(settings.l("启动应用直接黑屏", "Start app in absolute black"), isOn: $settings.value.launchBlack).accessibilityIdentifier("launch-black")
                            Text(settings.l("启动黑屏时也可按确认键显示控制，再选择退出。", "Press Select for controls, then Exit to return to the library.")).font(.caption).foregroundStyle(Palette.muted)
                        }
                    }.frame(maxWidth: .infinity).frame(height: 850)
                }
                RoutineShelf()
            }.padding(.horizontal, 80).padding(.top, 48).padding(.bottom, 56)
        }
    }

    /// 一键启动明确标注时长的纯黑睡前声景，不改动亮度及用户自己的音乐。
    private func startRoutine(_ sound: SoundKind) {
        playback.startWithSound(.black, sound: sound)
        playback.setSleep(sound == .rain ? 30 : 60)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @State private var address = ""
    @State private var photoError: String?
    @State private var confirmReset = false
    @State private var showingCredits = false
    @State private var showingDownloads = false
    @State private var showingSupport = false
    @State private var sitePage: SitePage?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "MAKE IT YOURS", title: settings.l("适合你的安静。", "Your kind of quiet."), subtitle: settings.l("本地保存偏好，没有账号，没有广告。", "Preferences stay on your device. No accounts. No ads."))
                .padding(.horizontal, 80).padding(.top, 24)
            Form {
                Section(settings.l("画面", "Picture")) {
                    ChoicePicker(title: settings.l("画面亮度", "Scene brightness"), selection: $settings.value.brightness,
                                 options: [0.1, 0.2, 0.4, 0.6, 0.8, 1].map { ($0, "\(Int($0 * 100))%") }).accessibilityIdentifier("brightness")
                    ChoicePicker(title: settings.l("动画速度", "Animation speed"), selection: $settings.value.speed,
                                 options: [(0.25, settings.l("很慢", "Very slow")), (0.5, settings.l("舒缓", "Gentle")), (1, settings.l("标准", "Normal"))])
                    Toggle(settings.l("叠加漂移时钟（纯黑除外）", "Floating clock (except black)"), isOn: $settings.value.showClock).accessibilityIdentifier("show-clock")
                    Toggle(settings.l("24 小时时钟", "24-hour clock"), isOn: $settings.value.clock24Hour)
                    Text(settings.l("亮度仅调整本应用画面，不改变电视背光。系统减少动态效果会冻结装饰动画。", "Brightness adjusts our picture, not your TV backlight. Reduce Motion freezes decorative animation.")).font(.caption).foregroundStyle(Palette.muted)
                }
                Section(settings.l("轮播与闲置", "Rotation & idle")) {
                    ChoicePicker(title: settings.l("收藏切换间隔", "Collection interval"), selection: $settings.value.rotationSeconds,
                                 options: [60, 180, 300, 600, 900].map { ($0, settings.l("\($0 / 60) 分钟", "\($0 / 60) minutes")) })
                    Toggle(settings.l("收藏随机播放", "Shuffle collection"), isOn: $settings.value.shuffle)
                    ChoicePicker(title: settings.l("库内闲置自动播放", "Start when library is idle"), selection: $settings.value.idleSeconds,
                                 options: [(0, settings.l("关闭", "Off"))] + [30, 60, 180, 300].map { ($0, settings.l("\($0) 秒", "\($0) seconds")) })
                }
                Section(settings.l("私人照片画廊", "Personal photo gallery")) {
                    Text(settings.l("添加 HTTPS 图片直链，最多 30 张。可使用 iPhone 的 Apple TV 遥控键盘输入。仅访问你添加的网站。", "Add up to 30 direct HTTPS image URLs. Use the Apple TV Remote keyboard on iPhone. Only your chosen websites are contacted.")).font(.caption).foregroundStyle(Palette.muted)
                    TextField(settings.l("HTTPS 图片地址", "HTTPS image URL"), text: $address).accessibilityIdentifier("photo-url")
                    Button(settings.l("添加照片", "Add photo")) {
                        photoError = settings.addPhoto(address)
                        if photoError == nil { address = "" }
                    }.accessibilityIdentifier("add-photo")
                    if let photoError { Text(photoError).foregroundStyle(.orange).font(.callout) }
                    ChoicePicker(title: settings.l("照片停留时间", "Photo interval"), selection: $settings.value.photoSeconds,
                                 options: [10, 30, 60, 120].map { ($0, settings.l("\($0) 秒", "\($0) seconds")) })
                    ForEach(Array(settings.value.photos.enumerated()), id: \.element) { index, photo in
                        Button {
                            settings.value.photos.removeAll { $0 == photo }
                        } label: {
                            HStack {
                                Text(settings.l("照片 \(index + 1)", "Photo \(index + 1)"))
                                Text(URL(string: photo)?.host ?? "").foregroundStyle(Palette.muted).lineLimit(1)
                                Spacer()
                                Label(settings.l("移除", "Remove"), systemImage: "trash")
                            }
                        }.accessibilityIdentifier("remove-photo-\(index)")
                    }
                    Text(settings.l("照片加载失败时保持暗色空白，可随时返回。照片需有使用授权。", "Failed photos remain dark; you can always go back. Use photographs you have permission to display.")).font(.caption).foregroundStyle(Palette.muted)
                }
                Section(settings.l("支持与帮助", "Support and help")) {
                    Button(settings.l("下载更多 4K 风景与原生录音", "Download more 4K films and field recordings")) { showingDownloads = true }.accessibilityIdentifier("open-downloads")
                    Button(settings.l("赞助开发", "Support development")) { showingSupport = true }.accessibilityIdentifier("support-development")
                    Text(settings.l("自愿打赏，全部功能免费。", "Optional tips. Every feature is free.")).font(.caption).foregroundStyle(Palette.muted)
                    ForEach(SitePage.allCases) { page in
                        Button(page.title(settings)) { sitePage = page }.accessibilityIdentifier("site-\(page.rawValue)")
                    }
                }
                Section(settings.l("语言与隐私", "Language & privacy")) {
                    ChoicePicker(title: "语言 / Language", selection: Binding(get: { settings.value.languageCode.flatMap(AppLanguage.init(rawValue:)) ?? (settings.value.english ? .en : .zhHans) }, set: { settings.setLanguage($0) }), options: AppLanguage.allCases.map { ($0, $0 == .system ? settings.l("跟随系统", "Automatic") : $0.name) }).accessibilityIdentifier("language")
                    Text(settings.l("没有统计、追踪或广告 SDK。不向开发者服务器上传数据。个人照片由你指定的地址提供，对方可能记录正常的网络访问。", "No analytics, tracking or advertising SDKs. Nothing is uploaded to developer servers. Photo hosts you choose may log normal network requests.")).font(.callout).foregroundStyle(Palette.muted)
                    Button(settings.l("视听素材来源与授权", "Media sources & licenses")) { showingCredits = true }.accessibilityIdentifier("media-credits")
                    Text("Nightfall TV \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · Code: MIT · github.com/ZanwingMak/NightfallTV").font(.caption).foregroundStyle(Palette.muted)
                    Button(settings.l("重置设置、方案与照片", "Reset preferences, routines and photos"), role: .destructive) { confirmReset = true }.accessibilityIdentifier("reset-settings")
                }
            }.padding(.horizontal, 80)
        }
        .sheet(isPresented: $showingCredits) { MediaCreditsView() }
        .sheet(isPresented: $showingDownloads) { DownloadsView() }
        .sheet(isPresented: $showingSupport) { SupportView() }
        .sheet(item: $sitePage) { SiteLinkView(page: $0) }
        .alert(settings.l("恢复默认设置？", "Reset to defaults?"), isPresented: $confirmReset) {
            Button(settings.l("取消", "Cancel"), role: .cancel) { }
            Button(settings.l("重置", "Reset"), role: .destructive) { sound.stop(); settings.reset(); playback.interaction(); address = ""; photoError = nil }
        } message: { Text(settings.l("会清空照片地址、收藏、睡前方案和个人偏好。", "This removes photo URLs, favorites, routines and preferences.")) }
    }
}

import SwiftUI

@main
struct NightfallTVApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var sound: SoundPlayer
    @StateObject private var downloads = DownloadStore.shared
    @StateObject private var tips = TipStore()
    @StateObject private var playback: PlaybackController

    /// 装配唯一的配置、声景和播放会话；测试参数仅在 Debug 构建生效。
    init() {
        let settings = SettingsStore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { settings.reset() }
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--language=") }), let language = AppLanguage(rawValue: String(argument.dropFirst(11))) { settings.setLanguage(language) }
        if ProcessInfo.processInfo.arguments.contains("--clock-overlay") { settings.value.showClock = true; settings.value.brightness = 1 }
        #endif
        let sound = SoundPlayer()
        _settings = StateObject(wrappedValue: settings)
        _sound = StateObject(wrappedValue: sound)
        _playback = StateObject(wrappedValue: PlaybackController(settings: settings, sound: sound))
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(settings).environmentObject(sound).environmentObject(playback).environmentObject(tips).environmentObject(downloads)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.59, green: 0.5, blue: 0.95))
        }
    }
}

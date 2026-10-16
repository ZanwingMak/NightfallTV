import SwiftUI

private enum AppPage: String, CaseIterable {
    case sounds, night, settings
    /// 返回顶部导航标题。
    func title(_ language: AppLanguage) -> String {
        let titles = [("声景", "Soundscapes"), ("静心", "Unwind"), ("设置", "Settings")]
        let pair = titles[Self.allCases.firstIndex(of: self)!]
        return Localizer.text(pair.1, chinese: pair.0, language: language)
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: AppPage = .sounds
    @State private var launched = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if playback.isPlaying {
                if playback.meditation != nil { MeditationView() } else { PlayerView() }
            } else {
                VStack(spacing: 28) {
                    navigation.padding(.horizontal, 72).padding(.top, 40).focusSection()
                    Group {
                        switch page {
                        case .sounds: SoundsView()
                        case .night: NightView()
                        case .settings: SettingsView()
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).focusSection()
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.locale, settings.language.locale)
        .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
        .pickerStyle(.menu)
        .onChange(of: scenePhase) { _, phase in
            playback.setActive(phase == .active)
            if phase == .active { downloads.refresh() }
        }
        .alert(settings.l("请先下载此内容", "Download this content first"), isPresented: $playback.mediaMissing) { Button(settings.l("好", "OK"), role: .cancel) {} } message: { Text(settings.l("在设置的下载库中重新下载，即可离线播放。", "Download it again from the library in Settings to play offline.")) }
        .onAppear {
            guard !launched else { return }
            launched = true
            #if DEBUG
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--scene=") }),
               let scene = SceneKind(rawValue: String(argument.dropFirst(8))) {
                playback.start(scene)
                return
            }
            #endif
        }
    }

    private var navigation: some View {
        HStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "moonphase.waning.crescent").font(.title2).foregroundStyle(Palette.accent)
                Text("nightfall sleep").font(.system(size: 28, weight: .medium, design: .rounded)).tracking(1)
            }
            Spacer()
            ForEach(AppPage.allCases, id: \.self) { item in
                Button { page = item; playback.interaction() } label: {
                    Text(item.title(settings.language)).font(.callout.weight(page == item ? .semibold : .regular))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .buttonStyle(NightButtonStyle(isSelected: page == item)).accessibilityAddTraits(page == item ? .isSelected : [])
                .accessibilityIdentifier("nav-\(item.rawValue)")
            }
        }
    }
}

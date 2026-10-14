import SwiftUI

private enum AppPage: String, CaseIterable {
    case explore, collection, sounds, night, settings
    /// 返回顶部导航标题。
    func title(_ language: AppLanguage) -> String {
        let titles = [("探索", "Explore"), ("收藏", "Collection"), ("声景", "Soundscapes"), ("夜间", "Nightfall"), ("设置", "Settings")]
        let pair = titles[Self.allCases.firstIndex(of: self)!]
        return Localizer.text(pair.1, chinese: pair.0, language: language)
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: AppPage = .explore
    @State private var detail: SceneKind?
    @State private var category = SceneCategory.all
    @State private var launched = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if playback.isPlaying {
                PlayerView()
            } else if let detail {
                SceneDetailView(scene: detail) { self.detail = nil; playback.interaction() }
            } else {
                VStack(spacing: 28) {
                    navigation.padding(.horizontal, 72).padding(.top, 40).focusSection()
                    Group {
                        switch page {
                        case .explore: LibraryView(category: $category) { detail = $0; playback.interaction() }
                        case .collection: CollectionView { detail = $0; playback.interaction() }
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
        .onChange(of: playback.now) { _, _ in
            if detail == nil && (page == .explore || page == .collection) { playback.checkIdle() }
        }
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
            if settings.value.launchBlack { playback.start(.black) }
        }
    }

    private var navigation: some View {
        HStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "moonphase.waning.crescent").font(.title2).foregroundStyle(Palette.accent)
                Text("nightfall").font(.system(size: 30, weight: .medium, design: .rounded)).tracking(2)
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

struct LibraryView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    @Binding var category: SceneCategory
    let open: (SceneKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                hero
                HStack(spacing: 20) {
                    ForEach(SceneCategory.allCases) { item in
                        Button { category = item; playback.interaction() } label: {
                            Text(item.title(settings.language)).font(.callout).padding(.horizontal, 16)
                        }.buttonStyle(NightButtonStyle(isSelected: category == item)).accessibilityAddTraits(category == item ? .isSelected : [])
                            .accessibilityIdentifier("category-\(item.rawValue)")
                    }
                    Spacer()
                    Text(settings.l("\(SceneKind.allCases.count) 个场景 · 无限安静", "\(SceneKind.allCases.count) scenes · endless calm")).font(.caption).foregroundStyle(Palette.muted)
                }.focusSection()
                FocusGrid(SceneKind.allCases.filter { !$0.isDownload && (category == .all || $0.category == category) }) { scene in
                    SceneCard(scene: scene) { open(scene) }
                }
                if category == .all || category == .nature {
                    PageHeading(eyebrow: "A WIDER WORLD", title: settings.l("4K 风景", "4K films"), subtitle: settings.l("先选喜欢的，再免费下载。", "Choose a favorite, then download it free."))
                    FocusGrid(SceneKind.allCases.filter(\.isDownload)) { scene in SceneCard(scene: scene) { open(scene) } }
                }
            }.padding(.horizontal, 80).padding(.top, 16).padding(.bottom, 48)
        }
        .accessibilityIdentifier("library")
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            SceneArtwork(kind: .aurora)
            LinearGradient(colors: [.black.opacity(0.86), .black.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 20) {
                Text(Localizer.text("A LITTLE LESS LIGHT. A LITTLE MORE PEACE.", language: settings.language)).font(.caption.weight(.medium)).tracking(3).foregroundStyle(Palette.accent)
                Text(settings.l("把夜晚，\n还给自己。", "Let the evening\nbelong to you.")).font(.system(size: 64, weight: .light)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Text(settings.l("从极光到星海，从一束暖光到完全黑屏。", "From northern lights to starlight. From a warm glow to none.")).font(.callout).foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 24) {
                    QuietButton(title: settings.l("探索极光", "Explore aurora"), symbol: "play.fill", id: "hero-aurora") { open(.aurora) }
                    QuietButton(title: settings.l("一键黑屏", "Go dark"), symbol: "moon.zzz.fill", id: "quick-black") { playback.start(.black) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16).focusSection()
            }.padding(48)
        }.frame(height: 560).clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
    }
}

struct CollectionView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    let open: (SceneKind) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                PageHeading(eyebrow: "YOUR QUIET CORNER", title: settings.l("只留下喜欢的。", "Only your favorites."), subtitle: settings.l("你的私人屏保播放列表。", "A personal playlist for your screen."))
                if settings.value.favorites.isEmpty {
                    EmptyPanel(symbol: "heart", title: settings.l("这里等着你的第一个收藏", "Your first favorite belongs here"), subtitle: settings.l("在探索中打开任意场景，选择收藏。", "Open a scene in Explore and add it to your collection."))
                } else {
                    HStack(spacing: 24) {
                        QuietButton(title: settings.l("播放收藏", "Play collection"), symbol: "play.fill", id: "play-collection") {
                            let available = settings.value.favorites.filter(\.isAvailable)
                            if let first = available.first { playback.start(first, playlist: available) }
                        }.disabled(!settings.value.favorites.contains(where: \.isAvailable))
                        QuietButton(title: settings.value.shuffle ? settings.l("随机播放：开", "Shuffle: on") : settings.l("随机播放：关", "Shuffle: off"), symbol: "shuffle", id: "shuffle") { settings.value.shuffle.toggle() }
                        Text(settings.l("共 \(settings.value.favorites.count) 个场景", "\(settings.value.favorites.count) scenes")).font(.callout).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).focusSection()
                    FocusGrid(settings.value.favorites) { scene in
                        SceneCard(scene: scene) { open(scene) }
                    }
                }
            }.padding(80)
        }
    }
}

struct SceneDetailView: View {
    let scene: SceneKind
    let close: () -> Void
    @State private var downloadAsset: DownloadAsset?
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SceneArtwork(kind: scene).ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.6), .black.opacity(0.98)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 24) {
                Text(scene.category.title(settings.language).uppercased()).font(.caption).tracking(4).foregroundStyle(Palette.accent)
                Text(scene.title(settings.language)).font(.system(size: 68, weight: .light))
                Text(scene.subtitle(settings.language)).font(.title3).foregroundStyle(.white.opacity(0.6))
                if scene == .gallery && settings.value.photos.isEmpty {
                    Text(settings.l("在设置中添加 HTTPS 照片地址，即可开始私人轮播。", "Add HTTPS photo URLs in Settings to begin your gallery.")).font(.callout).foregroundStyle(Palette.muted)
                }
                if scene == .black {
                    Text(settings.l("播放中没有提示。确认键显示控制，返回键退出。音乐由原播放器控制。", "No overlays while playing. Select opens controls. Back exits. Your music stays with its player.")).font(.callout).foregroundStyle(Palette.muted)
                }
                if let asset = DownloadAsset.scene(scene) {
                    Text(asset.specification + " · " + asset.size + " · " + asset.author + " · " + asset.license)
                        .font(.caption).foregroundStyle(Palette.muted)
                    if !scene.isAvailable {
                        VStack(alignment: .leading, spacing: 16) { DownloadActionButton(asset: asset) }.frame(width: 580)
                        if downloads.errors.contains(asset.id) {
                            Text(settings.l("下载未完成，请检查网络、可用空间后重试。", "Download incomplete. Check your connection and free space, then retry.")).font(.caption).foregroundStyle(Palette.accent)
                        }
                    }
                }
                HStack(spacing: 24) {
                    QuietButton(title: settings.l("开始屏保", "Start screensaver"), symbol: "play.fill", id: "start-scene") { playback.start(scene) }.disabled(!scene.isAvailable)
                    if let suggested = scene.suggestedSound {
                        QuietButton(title: settings.l("有声 · ", "With ") + suggested.title(settings.language), symbol: "speaker.wave.2.fill", id: "start-scene-sound") { playback.startWithSound(scene, sound: suggested) }.disabled(!scene.isAvailable || !suggested.isAvailable)
                    }
                    QuietButton(title: settings.value.favorites.contains(scene) ? settings.l("已收藏", "Saved") : settings.l("收藏场景", "Save scene"), symbol: settings.value.favorites.contains(scene) ? "heart.fill" : "heart", id: "favorite-scene") { settings.toggleFavorite(scene) }
                    QuietButton(title: settings.l("返回", "Back"), symbol: "arrow.left", id: "close-detail", action: close)
                }.padding(.top, 16)
                if let suggested = scene.suggestedSound, !suggested.isAvailable, let asset = DownloadAsset.sound(suggested) {
                    QuietButton(title: settings.l("下载推荐声景", "Download suggested sound"), symbol: "arrow.down.circle", id: "download-suggested-sound") { downloadAsset = asset }
                }
                if scene.suggestedSound != nil {
                    Text(settings.l("声音为独立自然录音。播放中可换声景、关画面或恢复画面。", "Sound is a separate field recording. Change it or turn the picture off and on while playing.")).font(.caption).foregroundStyle(Palette.muted)
                }
            }.padding(88)
        }.onExitCommand(perform: close).sheet(item: $downloadAsset) { asset in DownloadsView(filter: .audio, assetID: asset.id) }
    }
}

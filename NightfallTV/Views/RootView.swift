import SwiftUI

private enum AppPage: String, CaseIterable {
    case explore, collection, sounds, night, settings
    /// 返回顶部导航标题。
    func title(_ english: Bool) -> String {
        let titles = [("探索", "Explore"), ("收藏", "Collection"), ("声景", "Soundscapes"), ("夜间", "Nightfall"), ("设置", "Settings")]
        let pair = titles[Self.allCases.firstIndex(of: self)!]
        return english ? pair.1 : pair.0
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
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
        .pickerStyle(.menu)
        .onChange(of: scenePhase) { _, phase in playback.setActive(phase == .active) }
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
                    Text(item.title(settings.value.english)).font(.callout.weight(page == item ? .semibold : .regular))
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
                            Text(item.title(settings.value.english)).font(.callout).padding(.horizontal, 16)
                        }.buttonStyle(NightButtonStyle(isSelected: category == item)).accessibilityAddTraits(category == item ? .isSelected : [])
                            .accessibilityIdentifier("category-\(item.rawValue)")
                    }
                    Spacer()
                    Text(settings.l("10 个场景 · 无限安静", "10 scenes · endless calm")).font(.caption).foregroundStyle(Palette.muted)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 32) {
                    ForEach(SceneKind.allCases.filter { category == .all || $0.category == category }) { scene in
                        SceneCard(scene: scene) { open(scene) }
                    }
                }.padding(.bottom, 48)
            }.padding(.horizontal, 80).padding(.top, 16)
        }
        .accessibilityIdentifier("library")
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            SceneArtwork(kind: .aurora)
            LinearGradient(colors: [.black.opacity(0.86), .black.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 20) {
                Text("A LITTLE LESS LIGHT. A LITTLE MORE PEACE.").font(.caption.weight(.medium)).tracking(3).foregroundStyle(Palette.accent)
                Text(settings.l("把夜晚，\n还给自己。", "Let the evening\nbelong to you.")).font(.system(size: 64, weight: .light)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Text(settings.l("从极光到星海，从一束暖光到完全黑屏。", "From northern lights to starlight. From a warm glow to none.")).font(.callout).foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 24) {
                    QuietButton(title: settings.l("探索极光", "Explore aurora"), symbol: "play.fill", id: "hero-aurora") { open(.aurora) }
                    QuietButton(title: settings.l("一键黑屏", "Go dark"), symbol: "moon.zzz.fill", id: "quick-black") { playback.start(.black) }
                }.padding(.top, 16)
            }.padding(48)
        }.frame(height: 560).clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
    }
}

struct CollectionView: View {
    @EnvironmentObject private var settings: SettingsStore
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
                            if let first = settings.value.favorites.first { playback.start(first, playlist: settings.value.favorites) }
                        }
                        QuietButton(title: settings.value.shuffle ? settings.l("随机播放：开", "Shuffle: on") : settings.l("随机播放：关", "Shuffle: off"), symbol: "shuffle", id: "shuffle") { settings.value.shuffle.toggle() }
                        Text(settings.l("共 \(settings.value.favorites.count) 个场景", "\(settings.value.favorites.count) scenes")).font(.callout).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).focusSection()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: 3), spacing: 32) {
                        ForEach(settings.value.favorites) { scene in SceneCard(scene: scene) { open(scene) } }
                    }
                }
            }.padding(80)
        }
    }
}

struct SceneDetailView: View {
    let scene: SceneKind
    let close: () -> Void
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SceneArtwork(kind: scene).ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.6), .black.opacity(0.98)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 24) {
                Text(scene.category.title(settings.value.english).uppercased()).font(.caption).tracking(4).foregroundStyle(Palette.accent)
                Text(scene.title(settings.value.english)).font(.system(size: 68, weight: .light))
                Text(scene.subtitle(settings.value.english)).font(.title3).foregroundStyle(.white.opacity(0.6))
                if scene == .gallery && settings.value.photos.isEmpty {
                    Text(settings.l("在设置中添加 HTTPS 照片地址，即可开始私人轮播。", "Add HTTPS photo URLs in Settings to begin your gallery.")).font(.callout).foregroundStyle(Palette.muted)
                }
                if scene == .black {
                    Text(settings.l("播放中没有提示。确认键显示控制，返回键退出。音乐由原播放器控制。", "No overlays while playing. Select opens controls. Back exits. Your music stays with its player.")).font(.callout).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 24) {
                    QuietButton(title: settings.l("开始屏保", "Start screensaver"), symbol: "play.fill", id: "start-scene") { playback.start(scene) }
                    QuietButton(title: settings.value.favorites.contains(scene) ? settings.l("已收藏", "Saved") : settings.l("收藏场景", "Save scene"), symbol: settings.value.favorites.contains(scene) ? "heart.fill" : "heart", id: "favorite-scene") { settings.toggleFavorite(scene) }
                    QuietButton(title: settings.l("返回", "Back"), symbol: "arrow.left", id: "close-detail", action: close)
                }.padding(.top, 16)
            }.padding(88)
        }.onExitCommand(perform: close)
    }
}

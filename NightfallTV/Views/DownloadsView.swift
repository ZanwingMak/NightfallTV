import SwiftUI

enum DownloadFilter: String, CaseIterable, Identifiable {
    case all, films, audio, downloaded
    var id: String { rawValue }

    /// 分类使用现有本地化名称，离线资源独立于媒体类型筛选。
    @MainActor func title(_ settings: SettingsStore) -> String {
        switch self {
        case .all: return settings.l("全部", "All")
        case .films: return settings.l("4K 风景", "4K films")
        case .audio: return settings.l("声景", "Soundscapes")
        case .downloaded: return settings.l("已下载", "Downloaded")
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var filter: DownloadFilter
    private let assetID: String?

    /// 从场景或声景入口打开对应分类，并定位到用户选中的资源。
    init(filter: DownloadFilter = .all, assetID: String? = nil) {
        _filter = State(initialValue: filter)
        self.assetID = assetID
    }

    var body: some View {
        VStack(spacing: 28) {
            HStack(alignment: .top) {
                PageHeading(eyebrow: "A WIDER WORLD", title: settings.l("更多风景，按需收藏。", "More places. Only what you choose."), subtitle: settings.l("4K 实拍与无损自然录音。全部免费，只下载你想要的。", "4K films and lossless field recordings. Free to download, one favorite at a time."))
                QuietButton(title: settings.l("返回", "Back"), symbol: "xmark", id: "close-downloads") { dismiss() }
            }.focusSection()
            HStack(spacing: 20) {
                ForEach(DownloadFilter.allCases) { item in
                    Button { filter = item } label: { Text(item.title(settings)).font(.callout).padding(8) }
                        .buttonStyle(NightButtonStyle(isSelected: filter == item))
                        .accessibilityAddTraits(filter == item ? .isSelected : [])
                        .accessibilityIdentifier("download-filter-\(item.rawValue)")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(settings.l("本地缓存", "Local cache") + " · " + ByteCountFormatter.string(fromByteCount: downloads.cachedBytes, countStyle: .file))
                        .font(.caption).foregroundStyle(Palette.muted).accessibilityIdentifier("download-storage")
                    if !downloads.progress.isEmpty || !downloads.queued.isEmpty {
                        Text(settings.l("\(downloads.progress.count) 项下载中 · \(downloads.queued.count) 项排队", "\(downloads.progress.count) downloading · \(downloads.queued.count) queued"))
                            .font(.caption2).foregroundStyle(Palette.accent).accessibilityIdentifier("download-queue-status")
                    }
                }
                if !downloads.progress.isEmpty || !downloads.queued.isEmpty {
                    Button { downloads.cancelAll() } label: { Image(systemName: "xmark.circle").font(.callout).padding(8) }
                        .buttonStyle(NightButtonStyle()).accessibilityLabel(settings.l("取消全部下载", "Cancel all downloads"))
                        .accessibilityIdentifier("cancel-all-downloads")
                }
            }.frame(height: 80).focusSection()
            ScrollViewReader { proxy in
                ScrollView {
                    if assets.isEmpty {
                        EmptyPanel(symbol: "arrow.down.circle", title: settings.l("还没有下载内容", "No downloads yet"), subtitle: settings.l("选择喜欢的内容下载，即可离线播放。", "Download a favorite to play it offline."))
                    } else {
                        FocusGrid(assets) { asset in downloadCard(asset).id(asset.id) }.padding(12)
                    }
                    Text(settings.l("下载需要网络；离线时可播放已下载内容。tvOS 可能自动清理缓存，可随时免费下载。原作者和许可见每张卡片及素材来源。", "Internet is required to download. Downloaded content works offline. tvOS may clear its cache; downloading again is free. Each card credits its creator and license."))
                        .font(.caption).foregroundStyle(Palette.muted).padding(.top, 24)
                }.onAppear { if let assetID { proxy.scrollTo(assetID, anchor: .top) } }
            }
        }.padding(64).background(Palette.background).onAppear { downloads.refresh() }.onExitCommand { dismiss() }
    }

    private var assets: [DownloadAsset] {
        DownloadAsset.all.filter { asset in
            switch filter {
            case .all: return true
            case .films: return asset.scene != nil
            case .audio: return asset.sound != nil
            case .downloaded: return downloads.ready.contains(asset.id)
            }
        }
    }

    /// 资源卡显示真实规格、完整下载容量与明确的下载/取消/删除状态。
    private func downloadCard(_ asset: DownloadAsset) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                SceneArtwork(kind: asset.poster).frame(height: 200).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                Label(asset.specification, systemImage: asset.scene == nil ? "waveform" : "4k.tv").font(.caption).padding(20)
            }.clipShape(RoundedRectangle(cornerRadius: 16))
            Text(asset.title(settings.language)).font(.title3).lineLimit(2).minimumScaleFactor(0.8)
            Text(asset.size + " · " + asset.author + " · " + asset.license).font(.caption2).foregroundStyle(Palette.muted).lineLimit(2)
            if downloads.ready.contains(asset.id) {
                HStack(spacing: 18) {
                    QuietButton(title: asset.scene == nil ? settings.l("播放", "Play") : settings.l("打开画面", "Picture on"), symbol: "play.fill", id: "play-download-\(asset.id)") {
                        dismiss()
                        if let scene = asset.scene { playback.start(scene) }
                        else if let recording = asset.sound { playback.startWithSound(recording.visualScene, sound: recording) }
                    }
                    .disabled(asset.scene != nil && sound.selected == nil)
                    QuietButton(title: settings.l("删除下载", "Delete download"), symbol: "trash", id: "delete-\(asset.id)") {
                        if let recording = asset.sound, sound.layers.contains(where: { $0.sound == recording }) { playback.toggleSoundLayer(recording) }
                        downloads.remove(asset)
                    }
                }
                if asset.scene != nil && sound.selected == nil {
                    Text(settings.l("选择声音开始试听", "Select sounds to preview")).font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                DownloadActionButton(asset: asset)
            }
            if downloads.errors.contains(asset.id) {
                Text(settings.l("下载未完成，请检查网络、可用空间后重试。", "Download incomplete. Check your connection and free space, then retry.")).font(.caption2).foregroundStyle(Palette.accent)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24)).focusSection()
    }
}

struct DownloadActionButton: View {
    let asset: DownloadAsset
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let fraction = downloads.progress[asset.id] {
                ProgressView(value: fraction).tint(Palette.accent).accessibilityIdentifier("progress-\(asset.id)")
            }
            QuietButton(title: title, symbol: waiting ? "xmark" : "arrow.down.circle", id: identifier) {
                if waiting { downloads.cancel(asset) }
                else { downloads.download(asset) }
            }
        }
    }

    private var waiting: Bool { downloads.progress[asset.id] != nil || downloads.queued.contains(asset.id) }
    private var identifier: String {
        (downloads.progress[asset.id] != nil ? "cancel-" : (downloads.queued.contains(asset.id) ? "cancel-queued-" : "download-")) + asset.id
    }
    private var title: String {
        if let fraction = downloads.progress[asset.id] { return settings.l("取消下载", "Cancel download") + " · \(Int(fraction * 100))%" }
        if let index = downloads.queued.firstIndex(of: asset.id) { return settings.l("取消排队 · 第 \(index + 1) 项", "Cancel queued download · \(index + 1)") }
        return settings.l("免费下载", "Download free")
    }
}

import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var downloads: DownloadStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 28) {
            HStack(alignment: .top) {
                PageHeading(eyebrow: "A WIDER WORLD", title: settings.l("更多风景，按需收藏。", "More places. Only what you choose."), subtitle: settings.l("4K 实拍与无损自然录音。全部免费，只下载你想要的。", "4K films and lossless field recordings. Free to download, one favorite at a time."))
                QuietButton(title: settings.l("返回", "Back"), symbol: "xmark", id: "close-downloads") { dismiss() }
            }.focusSection()
            ScrollView {
                FocusGrid(DownloadAsset.all) { asset in downloadCard(asset) }.padding(12)
                Text(settings.l("下载需要网络；离线时可播放已下载内容。tvOS 可能自动清理缓存，可随时免费下载。原作者和许可见每张卡片及素材来源。", "Internet is required to download. Downloaded content works offline. tvOS may clear its cache; downloading again is free. Each card credits its creator and license."))
                    .font(.caption).foregroundStyle(Palette.muted).padding(.top, 24)
            }
        }.padding(64).background(Palette.background).onAppear { downloads.refresh() }.onExitCommand { dismiss() }
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
            if let fraction = downloads.progress[asset.id] {
                ProgressView(value: fraction).tint(Palette.accent).accessibilityIdentifier("progress-\(asset.id)")
                QuietButton(title: settings.l("取消下载", "Cancel download") + " · \(Int(fraction * 100))%", symbol: "xmark", id: "cancel-\(asset.id)") { downloads.cancel(asset) }
            } else if downloads.ready.contains(asset.id) {
                HStack(spacing: 18) {
                    QuietButton(title: settings.l("播放", "Play"), symbol: "play.fill", id: "play-download-\(asset.id)") {
                        dismiss()
                        if let scene = asset.scene { playback.start(scene) }
                        else if let recording = asset.sound { playback.startWithSound(recording.visualScene, sound: recording) }
                    }
                    QuietButton(title: settings.l("删除下载", "Delete download"), symbol: "trash", id: "delete-\(asset.id)") {
                        if let recording = asset.sound, sound.layers.contains(where: { $0.sound == recording }) { playback.toggleSoundLayer(recording) }
                        downloads.remove(asset)
                    }
                }
            } else {
                QuietButton(title: settings.l("免费下载", "Download free"), symbol: "arrow.down.circle", id: "download-\(asset.id)") { downloads.download(asset) }
                    .disabled(downloads.progress.count >= 2)
            }
            if downloads.errors.contains(asset.id) {
                Text(settings.l("下载未完成，请检查网络、可用空间后重试。", "Download incomplete. Check your connection and free space, then retry.")).font(.caption2).foregroundStyle(Palette.accent)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24)).focusSection()
    }
}

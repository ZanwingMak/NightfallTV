import SwiftUI

struct MediaCreditsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(settings.l("真实镜头，自由分享。", "Real footage. Openly shared.")).font(.title2)
                Spacer()
                QuietButton(title: settings.l("关闭", "Close"), symbol: "xmark", id: "close-credits") { dismiss() }
            }
            Text(settings.l("视频均为真实拍摄，静音、剪辑并转码；预览取自视频原帧。素材保留各自许可，代码使用 MIT。向下浏览完整署名与来源。", "All footage was filmed, trimmed, silenced and transcoded; previews are extracted frames. Media retain their own licenses; code is MIT. Scroll for credits and sources.")).font(.callout).foregroundStyle(Palette.muted)
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(VideoCredit.all) { credit in CreditRow(credit: credit) }
                }.padding(12)
            }
        }.padding(56).frame(width: 1440, height: 920).background(Palette.background)
            .onExitCommand { dismiss() }
    }
}

private struct CreditRow: View {
    let credit: VideoCredit
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(credit.scene.title(settings.value.english)).font(.title3)
            Text(credit.title + " · " + credit.creator).font(.callout)
            Text(credit.license).font(.callout).foregroundStyle(Palette.accent)
            Text(credit.sourceURL).font(.caption)
            Text(credit.licenseURL).font(.caption)
            Text(credit.changes).font(.caption).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(28)
            .background(.white.opacity(focused ? 0.09 : 0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(focused ? Palette.accent : .clear, lineWidth: 2))
            .focusable().focusEffectDisabled().focused($focused)
            .accessibilityIdentifier("credit-\(credit.scene.rawValue)")
    }
}

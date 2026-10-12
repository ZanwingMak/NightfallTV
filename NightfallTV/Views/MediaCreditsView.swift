import SwiftUI

struct MediaCreditsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(settings.l("真实视听，自由分享。", "Real sights and sounds. Openly shared.")).font(.title2)
                Spacer()
                QuietButton(title: settings.l("关闭", "Close"), symbol: "xmark", id: "close-credits") { dismiss() }
            }
            Text(settings.l("视频为真实拍摄，四种自然声景为真实录音。素材保留各自许可，代码与有色噪音使用 MIT。向下浏览作者、来源及修改说明。", "Videos are filmed; four nature sounds are field recordings. Media retain their licenses; code and colored noise are MIT. Scroll for creators, sources and edits.")).font(.callout).foregroundStyle(Palette.muted)
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(VideoCredit.all) { credit in
                        CreditRow(name: credit.scene.title(settings.value.english), title: credit.title, creator: credit.creator, license: credit.license,
                                  sourceURL: credit.sourceURL, licenseURL: credit.licenseURL, changes: credit.changes, id: "credit-\(credit.id)")
                    }
                    ForEach(AudioCredit.all) { credit in
                        CreditRow(name: credit.sound.title(settings.value.english), title: credit.title, creator: credit.creator, license: credit.license,
                                  sourceURL: credit.sourceURL, licenseURL: credit.licenseURL, changes: credit.sourceFormat + ". " + credit.changes, id: "audio-credit-\(credit.id)")
                    }
                }.padding(12)
            }
        }.padding(56).frame(width: 1440, height: 920).background(Palette.background)
            .onExitCommand { dismiss() }
    }
}

private struct CreditRow: View {
    let name: String
    let title: String
    let creator: String
    let license: String
    let sourceURL: String
    let licenseURL: String
    let changes: String
    let id: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name).font(.title3)
            Text(title + " · " + creator).font(.callout)
            Text(license).font(.callout).foregroundStyle(Palette.accent)
            Text(sourceURL).font(.caption)
            Text(licenseURL).font(.caption)
            Text(changes).font(.caption).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(28)
            .background(.white.opacity(focused ? 0.09 : 0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(focused ? Palette.accent : .clear, lineWidth: 2))
            .focusable().focusEffectDisabled().focused($focused)
            .accessibilityIdentifier(id)
    }
}

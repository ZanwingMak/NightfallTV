import SwiftUI

enum Palette {
    static let background = Color(red: 0.025, green: 0.025, blue: 0.045)
    static let muted = Color(red: 0.62, green: 0.64, blue: 0.72)
    static let accent = Color(red: 0.68, green: 0.6, blue: 1)
}

struct FocusGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let content: (Item) -> Card

    /// 将少量离线卡片排成三列，每行保留完整焦点区域，包括最后一行的空列。
    init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Card) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(spacing: 32) {
            ForEach(Array(stride(from: 0, to: items.count, by: 3)), id: \.self) { start in
                HStack(alignment: .top, spacing: 32) {
                    ForEach(0..<3, id: \.self) { column in
                        if start + column < items.count {
                            content(items[start + column]).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                }.focusSection()
            }
        }
    }
}

struct SceneCard: View {
    let scene: SceneKind
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var downloads: DownloadStore
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    SceneArtwork(kind: scene).aspectRatio(16 / 9, contentMode: .fit)
                    if scene == .black || scene == .clock || scene == .gallery {
                        Image(systemName: scene.symbol).font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.35)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                    HStack {
                        Text(scene.category.title(settings.language)).font(.caption).foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        if settings.value.favorites.contains(scene) { Image(systemName: "heart.fill").foregroundStyle(Palette.accent) }
                    }.padding(24)
                    if scene.isDownload {
                        VStack {
                            HStack {
                                Spacer()
                                Label(downloads.ready.contains(scene.rawValue) ? settings.l("已下载", "Downloaded") : settings.l("免费下载", "Download free"), systemImage: downloads.ready.contains(scene.rawValue) ? "checkmark.circle.fill" : "arrow.down.circle")
                                    .font(.caption2).padding(10).background(.black.opacity(0.75), in: Capsule())
                            }
                            Spacer()
                        }.padding(16)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(scene.title(settings.language)).font(.title3.weight(.medium)).foregroundStyle(.white)
                    Text(scene.subtitle(settings.language)).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.045))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.07)))
        }
        .buttonStyle(ArtworkButtonStyle())
        .accessibilityIdentifier("scene-\(scene.rawValue)")
        .accessibilityLabel(scene.title(settings.language) + (scene.isDownload ? " · " + (scene.isAvailable ? settings.l("已下载", "Downloaded") : settings.l("免费下载", "Download free")) : ""))
    }
}

struct ArtworkButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @EnvironmentObject private var playback: PlaybackController

    /// 保留深色卡片正文，以边框和轻微放大表现焦点，避免系统白底覆盖白色标题。
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(focused ? Palette.accent : .clear, lineWidth: 3))
            .scaleEffect(focused ? 1.025 : 1)
            .shadow(color: Palette.accent.opacity(focused ? 0.2 : 0), radius: 24)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .onChange(of: focused) { _, _ in playback.interaction() }
    }
}

struct PageHeading: View {
    @EnvironmentObject private var settings: SettingsStore
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localizer.text(eyebrow, language: settings.language).uppercased()).font(.caption.weight(.medium)).tracking(5).foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 54, weight: .light)).foregroundStyle(.white)
            Text(subtitle).font(.callout).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuietButton: View {
    let title: String
    let symbol: String
    var id: String = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.callout).padding(.horizontal, 12).padding(.vertical, 8) }
            .labelStyle(.titleAndIcon).buttonStyle(NightButtonStyle()).accessibilityIdentifier(id)
    }
}

struct NightButtonStyle: ButtonStyle {
    var isSelected = false
    @Environment(\.isFocused) private var focused
    @EnvironmentObject private var playback: PlaybackController
    /// 显式设置焦点与非焦点颜色，避免 tvOS 着色导致按钮文字不可见。
    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = focused ? .white : (isSelected ? Palette.accent.opacity(0.24) : Color.white.opacity(0.085))
        let border: Color = focused ? .white : (isSelected ? Palette.accent.opacity(0.75) : Color.white.opacity(0.08))
        return configuration.label
            .foregroundStyle(focused ? Color.black : Color.white.opacity(0.88))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(border))
            .scaleEffect(focused ? 1.04 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onChange(of: focused) { _, _ in playback.interaction() }
    }
}

struct EmptyPanel: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: symbol).font(.system(size: 68, weight: .ultraLight)).foregroundStyle(Palette.accent.opacity(0.6))
            Text(title).font(.title2)
            Text(subtitle).font(.callout).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(80).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ChoicePicker<Value: Equatable>: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]
    @State private var showingOptions = false
    @State private var previouslyChoosing = false

    var body: some View {
        Button { showingOptions = true } label: {
            HStack(spacing: 24) {
                Text(title)
                Spacer(minLength: 20)
                Text(options.first(where: { $0.0 == selection })?.1 ?? "")
                Image(systemName: "chevron.down").font(.caption)
            }.font(.callout).padding(.horizontal, 12)
        }.buttonStyle(NightButtonStyle())
            .accessibilityLabel(title + ", " + (options.first(where: { $0.0 == selection })?.1 ?? ""))
            .sheet(isPresented: $showingOptions, onDismiss: {
                playback.choosingOptions = previouslyChoosing
                playback.interaction()
            }) {
                VStack(spacing: 32) {
                    HStack {
                        Text(title).font(.title2)
                        Spacer()
                        Button { showingOptions = false } label: { Image(systemName: "xmark") }.buttonStyle(NightButtonStyle()).accessibilityLabel(settings.l("关闭", "Close")).accessibilityIdentifier("close-options")
                    }
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(options.indices, id: \.self) { index in
                                Button { selection = options[index].0; showingOptions = false } label: {
                                    HStack {
                                        Text(options[index].1)
                                        Spacer()
                                        if selection == options[index].0 { Image(systemName: "checkmark") }
                                    }.font(.callout).frame(maxWidth: .infinity).padding(12)
                                }.buttonStyle(NightButtonStyle()).accessibilityLabel(options[index].1)
                            }
                        }.padding(12)
                    }
                }.frame(width: 680).padding(56).background(Palette.background)
                    .onExitCommand { showingOptions = false }
            }
            .onChange(of: showingOptions) { _, showing in
                if showing { previouslyChoosing = playback.choosingOptions; playback.choosingOptions = true }
                else { playback.choosingOptions = previouslyChoosing }
                playback.interaction()
            }
    }
}

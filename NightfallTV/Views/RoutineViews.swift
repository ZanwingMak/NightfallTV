import SwiftUI

struct SoundMixerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                PageHeading(eyebrow: "YOUR OWN ATMOSPHERE", title: settings.l("调一份，自己的安静。", "Make your own quiet."),
                            subtitle: settings.l("最多 3 层。各层音量按比例混合，主音量控制整体响度。", "Up to 3 layers. Blend their relative levels; master volume controls the whole mix."))
                QuietButton(title: settings.l("完成", "Done"), symbol: "checkmark", id: "close-mixer") { dismiss() }
            }.focusSection()
            Text(sound.layers.isEmpty ? settings.l("选择声音开始试听", "Select sounds to preview") : sound.title(settings.language))
                .foregroundStyle(Palette.accent).font(.callout).accessibilityIdentifier("mixer-status")
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(SoundKind.available) { kind in
                        HStack(spacing: 32) {
                            Button { playback.toggleSoundLayer(kind) } label: {
                                HStack {
                                    Image(systemName: kind.symbol).frame(width: 48)
                                    Text(kind.title(settings.language))
                                    Spacer()
                                    Image(systemName: active(kind) ? "checkmark.circle.fill" : "plus.circle")
                                }.font(.callout).padding(12)
                            }.buttonStyle(NightButtonStyle(isSelected: active(kind))).frame(width: 520)
                                .disabled(!active(kind) && sound.layers.count >= 3)
                                .accessibilityIdentifier("mix-\(kind.rawValue)")
                            ChoicePicker(title: settings.l("占比", "Level"), selection: Binding(
                                get: { sound.layers.first(where: { $0.sound == kind })?.level ?? 1 },
                                set: { sound.setLevel($0, for: kind); playback.interaction() }),
                                options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                                .frame(width: 360).disabled(!active(kind)).accessibilityIdentifier("mix-level-\(kind.rawValue)")
                        }.focusSection()
                    }
                }.padding(20)
            }
            if let error = sound.error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                QuietButton(title: settings.l("全部停止", "Stop all"), symbol: "speaker.slash", id: "mix-stop") { sound.stop() }
                Text(settings.l("关闭画面不会停止混音；睡眠定时会一起淡出所有声层。", "Picture off keeps the mix playing. Sleep timer fades every layer together."))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }.frame(width: 1100, height: 850).padding(48).background(Palette.background)
            .onAppear { playback.choosingOptions = true }
            .onExitCommand { dismiss() }
    }

    /// 按实际混音成员显示选中态，避免把第一层误当作整个组合。
    private func active(_ kind: SoundKind) -> Bool { sound.layers.contains { $0.sound == kind } }
}

struct SaveRoutineView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageHeading(eyebrow: "KEEP THIS MOMENT", title: settings.l("下次，一键回到这里。", "Come back with one click."),
                        subtitle: settings.l("保存画面、声音组合、音量、亮度和两种定时。", "Save picture, sound mix, volume, brightness and both timers."))
            TextField(settings.l("方案名称", "Routine name"), text: $name).accessibilityIdentifier("routine-name")
            Text(playback.scene.title(settings.language) + " · " + (sound.layers.isEmpty ? settings.l("静音", "Silent") : sound.title(settings.language)))
                .font(.callout).foregroundStyle(Palette.muted)
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack(spacing: 32) {
                QuietButton(title: settings.l("保存方案", "Save routine"), symbol: "bookmark.fill", id: "confirm-save-routine") {
                    error = playback.saveRoutine(named: name)
                    if error == nil { dismiss() }
                }
                QuietButton(title: settings.l("取消", "Cancel"), symbol: "xmark", id: "cancel-save-routine") { dismiss() }
            }.focusSection()
            Text(settings.l("保存在「夜间 → 我的方案」。只存在这台 Apple TV，不会自动播放。", "Find it in Nightfall → My routines. Stored on this Apple TV; never starts automatically."))
                .font(.caption).foregroundStyle(Palette.muted)
        }.frame(width: 1100).padding(56).background(Palette.background)
            .onAppear { name = playback.scene.title(settings.language); playback.choosingOptions = true }
            .onExitCommand { dismiss() }
    }
}

struct RoutineShelf: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @State private var removing: SavedRoutine?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "SAVED FOR TONIGHT", title: settings.l("我的睡前方案", "My bedtime routines"),
                        subtitle: settings.l("在播放控制中保存喜欢的组合，下次直接开始。", "Save a combination in playback controls and start it here next time."))
            if settings.routines.isEmpty {
                Text(settings.l("例如：雨声 + 潮汐，先看云海，5 分钟后纯黑。", "Try rain + waves, watch clouds, then go dark after 5 minutes."))
                    .font(.callout).foregroundStyle(Palette.muted).padding(32)
                    .frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
            }
            ForEach(settings.routines) { routine in
                HStack(spacing: 32) {
                    SceneArtwork(kind: routine.scene).frame(width: 260, height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 12) {
                        Text(routine.name).font(.title3).lineLimit(1)
                        Text(routine.layers.isEmpty ? settings.l("静音", "Silent") : routine.layers.map { $0.sound.title(settings.language) }.joined(separator: " + "))
                            .font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                        Text(routine.sleepMinutes == 0 ? settings.l("不限时", "No sleep timer") : settings.l("\(routine.sleepMinutes) 分钟", "\(routine.sleepMinutes) minutes"))
                            .font(.caption).foregroundStyle(Palette.accent)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    QuietButton(title: settings.l("播放", "Play"), symbol: "play.fill", id: "routine-play-\(routine.id)") { playback.startRoutine(routine) }
                    QuietButton(title: settings.l("纯黑听", "Listen in black"), symbol: "moon.zzz.fill", id: "routine-black-\(routine.id)") { playback.startRoutine(routine, black: true) }
                    QuietButton(title: settings.l("移除", "Remove"), symbol: "trash", id: "routine-remove-\(routine.id)") { removing = routine }
                }.padding(24).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24)).focusSection()
            }
        }
        .alert(settings.l("移除这个方案？", "Remove this routine?"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing) { routine in
            Button(settings.l("取消", "Cancel"), role: .cancel) { removing = nil }
            Button(settings.l("移除", "Remove"), role: .destructive) {
                settings.removeRoutine(routine.id)
                removing = nil
            }
        } message: { routine in Text(routine.name) }
    }
}

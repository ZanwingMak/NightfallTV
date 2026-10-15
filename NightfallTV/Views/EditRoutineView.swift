import SwiftUI

struct EditRoutineView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SavedRoutine
    @State private var sounds: [SoundKind?]
    @State private var levels: [Double]
    @State private var error: String?

    /// 使用独立草稿编辑原方案；取消或返回不会写入配置，也不会开始播放。
    init(routine: SavedRoutine) {
        _draft = State(initialValue: routine)
        _sounds = State(initialValue: (0..<3).map { routine.layers.indices.contains($0) ? routine.layers[$0].sound : nil })
        _levels = State(initialValue: (0..<3).map { routine.layers.indices.contains($0) ? routine.layers[$0].level : 1 })
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 24) {
                PageHeading(eyebrow: "SAVED FOR TONIGHT", title: settings.l("编辑睡前方案", "Edit bedtime routine"),
                            subtitle: settings.l("修改下次播放的组合，不打断当前声音。", "Change the next playback without interrupting your sound."))
                QuietButton(title: settings.l("取消", "Cancel"), symbol: "xmark", id: "cancel-edit-routine") { dismiss() }
                QuietButton(title: settings.l("保存", "Save"), symbol: "checkmark", id: "save-edit-routine", action: save)
            }.focusSection()
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            Form {
                Section(settings.l("方案名称", "Routine name")) {
                    NightTextField(title: settings.l("方案名称", "Routine name"), text: $draft.name).accessibilityIdentifier("edit-routine-name")
                }
                Section(settings.l("画面", "Picture")) {
                    ChoicePicker(title: settings.l("搭配画面", "Picture"), selection: $draft.scene,
                                 options: SceneKind.allCases.filter { !$0.isPlayerMode && ($0.isAvailable || $0 == draft.scene) }.map { ($0, $0.title(settings.language)) })
                        .accessibilityIdentifier("edit-routine-scene")
                    Toggle(settings.l("关闭画面", "Picture off"), isOn: $draft.pictureOff).accessibilityIdentifier("edit-routine-black")
                    ChoicePicker(title: settings.l("画面亮度", "Scene brightness"), selection: $draft.brightness,
                                 options: [0.1, 0.2, 0.4, 0.6, 0.8, 1].map { ($0, "\(Int($0 * 100))%") })
                        .accessibilityIdentifier("edit-routine-brightness")
                }
                Section(settings.l("混合声景", "Mix sounds")) {
                    ForEach(0..<3, id: \.self) { index in
                        ChoicePicker(title: settings.l("声层 \(index + 1)", "Layer \(index + 1)"), selection: $sounds[index], options: soundOptions(index))
                            .accessibilityIdentifier("edit-routine-sound-\(index)")
                        ChoicePicker(title: settings.l("占比", "Level"), selection: $levels[index],
                                     options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                            .disabled(sounds[index] == nil).accessibilityIdentifier("edit-routine-level-\(index)")
                    }
                    ChoicePicker(title: settings.l("声景音量", "Sound volume"), selection: $draft.volume,
                                 options: [0.1, 0.25, 0.5, 0.75, 1].map { ($0, "\(Int($0 * 100))%") })
                        .accessibilityIdentifier("edit-routine-volume")
                }
                Section(settings.l("睡眠定时", "Sleep timer")) {
                    ChoicePicker(title: settings.l("睡眠定时", "Sleep timer"), selection: $draft.sleepMinutes,
                                 options: [(0, settings.l("关闭", "Off"))] + [15, 30, 60, 90, 120].map { ($0, settings.l("\($0) 分钟", "\($0) min")) })
                        .accessibilityIdentifier("edit-routine-timer")
                    ChoicePicker(title: settings.l("自动黑屏", "Picture timer"), selection: $draft.pictureOffMinutes,
                                 options: [(0, settings.l("关闭", "Off"))] + [1, 5, 10, 15, 30].map { ($0, settings.l("\($0) 分钟后", "After \($0) min")) })
                        .accessibilityIdentifier("edit-routine-picture-timer")
                }
            }
        }.frame(width: 1500, height: 820).padding(48).background(Palette.background).onExitCommand { dismiss() }
    }

    /// 排除其他声层已选的声音，保留原方案中暂时丢失的下载项以免静默修改。
    private func soundOptions(_ index: Int) -> [(SoundKind?, String)] {
        [(nil, settings.l("静音", "Silent"))] + SoundKind.allCases.filter {
            ($0.isAvailable && !sounds.contains($0)) || $0 == sounds[index]
        }.map { (Optional($0), $0.title(settings.language)) }
    }

    /// 原位保存草稿并保留方案标识，混音中空的声层不会被写入。
    private func save() {
        draft.layers = sounds.indices.compactMap { index in sounds[index].map { SoundLayer(sound: $0, level: levels[index]) } }
        error = settings.updateRoutine(draft)
        if error == nil { dismiss() }
    }
}

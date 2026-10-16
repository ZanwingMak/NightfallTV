import SwiftUI

struct MeditationSetupView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 10
    @State private var rhythm = BreathingRhythm.gentle
    @State private var selectedSound = SoundKind.stream
    @State private var voice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageHeading(eyebrow: "SLEEP · MEDITATE · UNWIND", title: settings.l("呼吸引导", "Guided breathing"),
                        subtitle: settings.l("随圆环舒展吸气，收拢呼气。按自己舒适的节奏练习。", "Breathe in as the circle grows, out as it settles. Find a comfortable pace."))
            ChoicePicker(title: settings.l("练习时长", "Session length"), selection: $minutes,
                         options: [5, 10, 20].map { ($0, settings.l("\($0) 分钟", "\($0) min")) }).accessibilityIdentifier("meditation-duration")
            ChoicePicker(title: settings.l("呼吸节奏", "Breathing rhythm"), selection: $rhythm,
                         options: [(.gentle, settings.l("吸气 4 秒 · 呼气 6 秒", "In 4s · out 6s")), (.balanced, settings.l("吸气 4 秒 · 呼气 4 秒", "In 4s · out 4s"))]).accessibilityIdentifier("meditation-rhythm")
            ChoicePicker(title: settings.l("声景", "Soundscapes"), selection: $selectedSound,
                         options: SoundKind.available.map { ($0, $0.title(settings.language)) }).accessibilityIdentifier("meditation-sound")
            Toggle(settings.l("语音节奏提示", "Spoken rhythm cues"), isOn: $voice).disabled(!playback.meditationVoiceAvailable)
                .accessibilityIdentifier("meditation-voice")
            Text(playback.meditationVoiceAvailable ? settings.l("可选系统语音提示吸气与呼气，关闭画面后也能跟随。", "Optional system voice says when to breathe in and out, even with the picture off.") : settings.l("此设备暂未提供所选语言的系统语音。", "A system voice for this language is unavailable on this device."))
                .font(.caption).foregroundStyle(Palette.muted)
            HStack(spacing: 24) {
                QuietButton(title: settings.l("开始练习", "Begin session"), symbol: "play.fill", id: "begin-meditation") {
                    dismiss()
                    playback.startMeditation(minutes: minutes, rhythm: rhythm, sound: selectedSound, voice: voice)
                }
                QuietButton(title: settings.l("取消", "Cancel"), symbol: "xmark", id: "cancel-meditation") { dismiss() }
            }.focusSection()
        }.frame(width: 1200).padding(56).background(Palette.background).onExitCommand { dismiss() }
    }
}

struct MeditationView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var sound: SoundPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var screenFocused: Bool
    @FocusState private var pauseFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea().focusable(!playback.controlsVisible).focusEffectDisabled().focused($screenFocused)
                .onTapGesture { playback.showControls() }
                .onMoveCommand { _ in if playback.effectiveScene != .black { playback.showControls() } }
                .accessibilityIdentifier(playback.effectiveScene == .black ? "meditation-black" : "meditation-stage")
                .accessibilityLabel(settings.l("播放器。按确认键打开控制。", "Playback. Press Select for controls."))
            if playback.effectiveScene == .black && !playback.controlsVisible {
                Color.clear.allowsHitTesting(false)
            } else if let session = playback.meditation {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(settings.l("呼吸引导", "Guided breathing")).font(.title2)
                            Text(sound.title(settings.language)).font(.callout).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Text(timeRemaining(session)).font(.system(size: 54, weight: .light, design: .rounded)).monospacedDigit()
                            .accessibilityIdentifier("meditation-remaining")
                    }
                    ZStack {
                        Circle().stroke(Palette.accent.opacity(0.12), lineWidth: 2).frame(width: 370, height: 370)
                        Circle().fill(RadialGradient(colors: [Palette.accent.opacity(0.3), Palette.accent.opacity(0.04)], center: .center, startRadius: 30, endRadius: 190))
                            .overlay(Circle().stroke(Palette.accent.opacity(0.65), lineWidth: 2))
                            .frame(width: 370, height: 370)
                            .scaleEffect(reduceMotion || session.finished ? 0.84 : session.circleScale(elapsed: playback.visualElapsed))
                            .animation(reduceMotion || playback.paused ? nil : .linear(duration: 1), value: playback.now)
                        VStack(spacing: 12) {
                            Text(phaseTitle(session)).font(.system(size: 56, weight: .light)).lineLimit(1).minimumScaleFactor(0.5).frame(width: 320).accessibilityIdentifier("meditation-phase")
                            if !session.finished {
                                Text("\(session.phaseRemaining(elapsed: playback.visualElapsed))").font(.title3.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                        }
                    }.frame(height: 410).accessibilityElement(children: .ignore).accessibilityLabel(phaseTitle(session))
                    ProgressView(value: min(1, playback.visualElapsed / session.duration)).tint(Palette.accent)
                    Group { if playback.controlsVisible { HStack(spacing: 24) {
                        QuietButton(title: playback.paused ? settings.l("继续", "Resume") : settings.l("暂停", "Pause"), symbol: playback.paused ? "play.fill" : "pause.fill", id: "meditation-pause") { playback.togglePause() }
                            .focused($pauseFocused).disabled(session.finished)
                        QuietButton(title: settings.l("语音节奏提示", "Spoken rhythm cues") + " · " + (session.voiceEnabled ? settings.l("开启", "On") : settings.l("关闭", "Off")), symbol: session.voiceEnabled ? "speaker.wave.2" : "speaker.slash", id: "meditation-toggle-voice") { playback.toggleMeditationVoice() }
                            .disabled(!playback.meditationVoiceAvailable || session.finished)
                        QuietButton(title: playback.effectiveScene == .black ? settings.l("打开画面", "Picture on") : settings.l("关闭画面", "Picture off"), symbol: "moon.zzz", id: "meditation-picture") { playback.toggleVisuals() }
                            .disabled(session.finished || settings.value.isNight(at: playback.now))
                        QuietButton(title: settings.l("退出", "Exit"), symbol: "xmark", id: "end-meditation") { playback.stop() }
                    }.frame(maxWidth: .infinity, alignment: .leading).focusSection() } else { Color.clear } }.frame(height: 92)
                    Text(settings.l("随圆环舒展吸气，收拢呼气。按自己舒适的节奏练习。", "Breathe in as the circle grows, out as it settles. Find a comfortable pace."))
                        .font(.caption).foregroundStyle(Palette.muted)
                }.padding(88)
            }
        }.background(.black).ignoresSafeArea()
            .onPlayPauseCommand { if playback.meditation?.finished == false { playback.togglePause() } }
            .onExitCommand { playback.back() }
            .onAppear { screenFocused = playback.effectiveScene == .black; pauseFocused = playback.effectiveScene != .black }
            .onChange(of: playback.controlsVisible) { _, visible in screenFocused = !visible; pauseFocused = visible }
    }

    /// 只显示有效练习时间；暂停不会消耗剩余分钟。
    private func timeRemaining(_ session: MeditationSession) -> String {
        let seconds = session.remaining(elapsed: playback.visualElapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// 完成和暂停优先于呼吸阶段，避免继续要求用户跟随已经停止的计时。
    private func phaseTitle(_ session: MeditationSession) -> String {
        if session.finished { return settings.l("练习完成", "Session complete") }
        if playback.paused { return settings.l("暂停", "Pause") }
        return session.inhaling(elapsed: playback.visualElapsed) ? settings.l("吸气", "Breathe in") : settings.l("呼气", "Breathe out")
    }
}

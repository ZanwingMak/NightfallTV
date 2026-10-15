import Foundation
import Combine

struct Preferences: Codable, Equatable {
    var english = false
    var languageCode: String?
    var favorites: [SceneKind] = [.aurora, .stars, .ocean]
    var brightness = 0.8
    var speed = 0.5
    var showClock = false
    var clock24Hour = true
    var shuffle = true
    var rotationSeconds = 300
    var photoSeconds = 30
    var sleepMinutes = 0
    var pictureOffMinutes: Int? = 0
    var soundVolume = 0.25
    var nightEnabled = false
    var nightStartHour = 23
    var nightEndHour = 7
    var launchBlack = false
    var idleSeconds = 0
    var lastScene: SceneKind = .aurora
    var photos: [String] = []

    /// 将持久化参数约束在支持范围内，移除重复及不安全的照片地址。
    mutating func normalize() {
        brightness = brightness.isFinite ? min(1, max(0.05, brightness)) : 0.8
        speed = speed.isFinite ? min(1, max(0.1, speed)) : 0.5
        soundVolume = soundVolume.isFinite ? min(1, max(0, soundVolume)) : 0.25
        rotationSeconds = [60, 180, 300, 600, 900].contains(rotationSeconds) ? rotationSeconds : 300
        photoSeconds = [10, 30, 60, 120].contains(photoSeconds) ? photoSeconds : 30
        sleepMinutes = [0, 15, 30, 60, 90, 120].contains(sleepMinutes) ? sleepMinutes : 0
        pictureOffMinutes = [0, 1, 5, 10, 15, 30].contains(pictureOffMinutes ?? 0) ? pictureOffMinutes ?? 0 : 0
        // 旧配置仅用于解码兼容；新版必须由用户明确开始播放。
        idleSeconds = 0
        launchBlack = false
        if lastScene.isPlayerMode { lastScene = .aurora }
        nightStartHour = min(23, max(0, nightStartHour))
        nightEndHour = min(23, max(0, nightEndHour))
        favorites = favorites.filter { !$0.isPlayerMode }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        photos = Array(photos.filter { Self.validPhotoURL($0) }.reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
        }.prefix(30))
    }

    /// 验证只接受无凭证、有主机的 HTTPS 图片地址。
    static func validPhotoURL(_ value: String) -> Bool {
        guard value.count <= 2048, let url = URL(string: value), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return false }
        return !value.contains(where: { $0.isWhitespace })
    }

    /// 按设备本地时间计算夜间窗口，支持跨午夜和全天。
    func isNight(at date: Date, calendar: Calendar = .current) -> Bool {
        guard nightEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        if nightStartHour == nightEndHour { return true }
        if nightStartHour < nightEndHour { return hour >= nightStartHour && hour < nightEndHour }
        return hour >= nightStartHour || hour < nightEndHour
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var value: Preferences { didSet { save() } }
    @Published private(set) var routines: [SavedRoutine] = []
    private let defaults: UserDefaults
    private let key = "nightfall.preferences.v1"

    /// 从本地偏好恢复配置；损坏数据回退默认值。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var decoded = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        decoded.normalize()
        if defaults.data(forKey: key) == nil { decoded.languageCode = AppLanguage.system.rawValue }
        value = decoded
        routines = (defaults.data(forKey: "nightfall.routines.v1").flatMap { try? JSONDecoder().decode([SavedRoutine].self, from: $0) } ?? [])
            .prefix(12).compactMap { entry in
                var safe = entry
                safe.normalize()
                return safe.name.isEmpty ? nil : safe
            }
    }

    /// 保存已归一化的偏好，不记录个人图片地址到日志。
    private func save() {
        var safe = value
        safe.normalize()
        if let data = try? JSONEncoder().encode(safe) { defaults.set(data, forKey: key) }
    }

    /// 添加或移除一个收藏场景。
    func toggleFavorite(_ scene: SceneKind) {
        if value.favorites.contains(scene) { value.favorites.removeAll { $0 == scene } }
        else { value.favorites.append(scene) }
    }

    /// 验证并保存照片地址，返回可显示的错误文案。
    func addPhoto(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Preferences.validPhotoURL(text) else { return l("请输入有效的 HTTPS 图片地址（不能包含用户名或密码）。", "Enter a valid HTTPS image URL without credentials.") }
        guard !value.photos.contains(text) else { return l("这张照片已经添加。", "This photo is already in your gallery.") }
        guard value.photos.count < 30 else { return l("最多可以添加 30 张照片。", "Your gallery can contain up to 30 photos.") }
        value.photos.append(text)
        return nil
    }

    /// 恢复全部偏好，保留由界面提供的确认流程。
    func reset() { value = Preferences(); routines = []; defaults.removeObject(forKey: "nightfall.routines.v1") }

    /// 保存当前播放组合，返回本地化错误；满十二项时让用户主动删除旧方案。
    func addRoutine(_ routine: SavedRoutine) -> String? {
        var safe = routine
        safe.normalize()
        guard !safe.name.isEmpty else { return l("请输入方案名称。", "Enter a name.") }
        guard routines.count < 12 else { return l("最多保存 12 个方案，请先移除一个。", "Remove a routine before saving more than 12.") }
        routines.append(safe)
        saveRoutines()
        return nil
    }

    /// 移除用户确认删除的个人方案，不影响当前播放。
    func removeRoutine(_ id: String) { routines.removeAll { $0.id == id }; saveRoutines() }

    /// 编辑使用原方案标识并原位保存，不占用额外名额，也不改变正在播放的会话。
    func updateRoutine(_ routine: SavedRoutine) -> String? {
        var safe = routine
        safe.normalize()
        guard !safe.name.isEmpty else { return l("请输入方案名称。", "Enter a name.") }
        guard let index = routines.firstIndex(where: { $0.id == safe.id }) else { return l("这个方案已被移除。", "This routine was removed.") }
        routines[index] = safe
        saveRoutines()
        return nil
    }

    /// 将个人方案与原偏好分开保存，兼容已有版本的配置。
    private func saveRoutines() {
        if let data = try? JSONEncoder().encode(routines) { defaults.set(data, forKey: "nightfall.routines.v1") }
    }

    /// 选择当前语言对应的界面文案。
    func l(_ chinese: String, _ english: String) -> String { Localizer.text(english, chinese: chinese, language: language) }

    var language: AppLanguage { (value.languageCode.flatMap(AppLanguage.init(rawValue:)) ?? (value.english ? .en : .zhHans)).resolved }

    /// 保存语言选择，同时保留旧版本的布尔偏好兼容信息。
    func setLanguage(_ language: AppLanguage) { value.languageCode = language.rawValue; value.english = language.resolved == .en }
}

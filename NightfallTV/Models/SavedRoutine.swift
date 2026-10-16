import Foundation

struct SoundLayer: Codable, Equatable, Identifiable {
    let sound: SoundKind
    var level: Double = 1
    var id: SoundKind { sound }

    /// 去重并限制为三层，清除无效音量，避免损坏的存储触发异常播放。
    static func normalized(_ layers: [SoundLayer]) -> [SoundLayer] {
        var result: [SoundLayer] = []
        for layer in layers where !result.contains(where: { $0.sound == layer.sound }) {
            result.append(SoundLayer(sound: layer.sound, level: layer.level.isFinite ? min(1, max(0.1, layer.level)) : 1))
            if result.count == 3 { break }
        }
        return result
    }
}

struct SavedRoutine: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var scene: SceneKind
    var pictureOff: Bool
    var layers: [SoundLayer]
    var volume: Double
    var brightness: Double
    var sleepMinutes: Int
    var pictureOffMinutes: Int

    /// 兼容旧方案并迁移已移除的时钟和照片背景；空混音明确恢复为细雨。
    mutating func normalize() {
        name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if scene == .black { scene = .aurora; pictureOff = true }
        if scene == .clock || scene == .gallery { scene = .aurora }
        layers = SoundLayer.normalized(layers)
        if layers.isEmpty { layers = [SoundLayer(sound: .rain)] }
        var preferences = Preferences()
        preferences.soundVolume = volume
        preferences.brightness = brightness
        preferences.sleepMinutes = sleepMinutes
        preferences.pictureOffMinutes = pictureOffMinutes
        preferences.normalize()
        volume = preferences.soundVolume
        brightness = preferences.brightness
        sleepMinutes = preferences.sleepMinutes
        pictureOffMinutes = preferences.pictureOffMinutes ?? 0
    }
}

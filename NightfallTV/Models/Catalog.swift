import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case black, aurora, stars, ocean, ember, dunes, prism, rain, clock, gallery, waterfall, snow, clouds, coast, mountains, valley, rhine
    var id: String { rawValue }
    var isDownload: Bool { [.coast, .mountains, .valley, .rhine].contains(self) }
    var isAvailable: Bool { !isDownload || DownloadAsset.scene(self).flatMap(DownloadStore.fileURL) != nil }
    var isPlayerMode: Bool { self == .black || self == .clock }
    static var available: [SceneKind] { allCases.filter { !$0.isPlayerMode && $0.isAvailable } }

    /// 返回场景的中英文名称。
    func title(_ english: Bool) -> String {
        let names: [SceneKind: (String, String)] = [
            .black: ("黑屏聆听", "Dark listening"), .aurora: ("极光之境", "Northern lights"),
            .stars: ("漫游星河", "Stellar drift"), .ocean: ("静海潮汐", "Ocean tides"),
            .ember: ("余烬炉火", "Quiet embers"), .dunes: ("沙漠落日", "Desert sunset"),
            .prism: ("林间树影", "Forest light"), .rain: ("雨落窗前", "Rain on glass"),
            .clock: ("时间缓行", "Slow hours"), .gallery: ("私人画廊", "Personal gallery"),
            .waterfall: ("庭园飞瀑", "Garden waterfall"), .snow: ("雪落无声", "Soft snowfall"),
            .clouds: ("云海漫行", "Cloud wander"), .coast: ("雨后海岸", "After the storm"),
            .mountains: ("山间清风", "Mountain quiet"), .valley: ("碧谷流云", "Emerald valley"), .rhine: ("莱茵飞瀑", "Rhine Falls")
        ]
        return english ? names[self]!.1 : names[self]!.0
    }

    /// 提供简短、真实的场景描述。
    func subtitle(_ english: Bool) -> String {
        let values: [SceneKind: (String, String)] = [
            .black: ("关掉画面，让声音陪你休息", "Picture off. Sound for your moment of rest."),
            .aurora: ("拉普兰的真实极光，静静流动", "Real northern lights, filmed in Lapland."),
            .stars: ("真实夜空，星轨缓行", "A time-lapse of the real night sky."),
            .ocean: ("曼利海滩的潮汐，真实俯拍", "Waves filmed above Manly Beach."),
            .ember: ("一团暖光，一段安静的时间", "A little warmth for a quiet evening."),
            .dunes: ("莫哈韦沙漠，真实日落", "A real sunset over the Mojave Desert."),
            .prism: ("实拍林间光影，随风轻动", "Filmed sunlight moving through trees."),
            .rain: ("拉斯帕尔马斯，真实雨夜", "A rainy night filmed in Las Palmas."),
            .clock: ("低亮时钟，随时间缓慢漂移", "A dim clock that gently changes position."),
            .gallery: ("把你喜欢的照片，留在大屏上", "Your favorite photographs, beautifully framed."),
            .waterfall: ("真实瀑布与岩石，水流不息", "A filmed waterfall flowing over rocks."),
            .snow: ("华盛顿州的真实飘雪，慢慢落下", "Real slow-motion snowfall in Washington state."),
            .clouds: ("真实天空延时摄影，云影流动", "Clouds drifting across a filmed sky."),
            .coast: ("圣巴巴拉雨后海岸，4K 实拍", "The Santa Barbara coast, filmed in 4K."),
            .mountains: ("真实群山与森林，4K 航拍", "Real mountains and forests, filmed in 4K."),
            .valley: ("山谷与云雾，4K 航拍实景", "A misty valley, filmed by a 4K drone."),
            .rhine: ("瑞士莱茵瀑布，4K 实拍", "Rhine Falls in Switzerland, filmed in 4K.")
        ]
        return english ? values[self]!.1 : values[self]!.0
    }

    var symbol: String {
        switch self {
        case .black: return "moon.zzz.fill"
        case .aurora: return "sparkles"
        case .stars: return "star.fill"
        case .ocean: return "water.waves"
        case .ember: return "flame.fill"
        case .dunes: return "sun.haze.fill"
        case .prism: return "leaf.fill"
        case .rain: return "cloud.rain.fill"
        case .clock: return "clock.fill"
        case .gallery: return "photo.on.rectangle.angled"
        case .waterfall: return "water.waves"
        case .snow: return "snowflake"
        case .clouds: return "cloud.fill"
        case .rhine: return "water.waves"
        case .coast: return "water.waves"
        case .mountains, .valley: return "mountain.2.fill"
        }
    }

    var category: SceneCategory {
        switch self {
        case .black, .clock: return .night
        case .aurora, .stars, .ocean, .ember, .dunes, .prism, .rain, .waterfall, .snow, .clouds, .coast, .mountains, .valley, .rhine: return .nature
        case .gallery: return .personal
        }
    }

    var suggestedSound: SoundKind? {
        switch self {
        case .ocean, .coast: return .ocean
        case .ember: return .fire
        case .rain: return .rain
        case .waterfall: return .waterfall
        case .prism: return .birds
        case .aurora, .stars: return .crickets
        case .dunes, .snow, .clouds, .mountains: return .wind
        case .valley: return .parkriver
        case .rhine: return .waterfall
        case .black, .clock, .gallery: return nil
        }
    }
}

enum SceneCategory: String, CaseIterable, Identifiable {
    case all, nature, night, personal
    var id: String { rawValue }
    /// 返回分类标题。
    func title(_ english: Bool) -> String {
        let values = [("全部", "All"), ("实拍", "Filmed"), ("夜景", "Night films"), ("照片", "Photos")]
        let pair = values[Self.allCases.firstIndex(of: self)!]
        return english ? pair.1 : pair.0
    }
}

enum SoundKind: String, CaseIterable, Codable, Identifiable {
    case rain, ocean, stream, fire, pink, brown, birds, crickets, wind, waterfall, thunder, parkbirds, parkriver, parkwind, white
    var id: String { rawValue }
    /// 返回声景的本地化标题。
    func title(_ english: Bool) -> String {
        let values = [("细雨", "Soft rain"), ("潮汐", "Ocean tide"), ("溪流", "Forest stream"), ("炉火", "Fireplace"), ("粉噪音", "Pink noise"), ("棕噪音", "Brown noise"), ("林间鸟鸣", "Forest birds"), ("夏夜虫鸣", "Summer crickets"), ("风过树叶", "Rustling leaves"), ("瀑布", "Waterfall"), ("远雷细雨", "Distant thunder"), ("公园晨鸟", "Park birds"), ("河畔水声", "Riverside"), ("旷野轻风", "Open-field wind"), ("白噪音", "White noise")]
        let pair = values[Self.allCases.firstIndex(of: self)!]
        return english ? pair.1 : pair.0
    }
    var symbol: String {
        ["cloud.rain.fill", "water.waves", "drop.fill", "flame.fill", "waveform", "waveform.path", "bird.fill", "moon.stars.fill", "wind", "water.waves", "cloud.bolt.rain.fill", "bird.fill", "water.waves", "wind", "waveform"][Self.allCases.firstIndex(of: self)!]
    }
    var isDownload: Bool { [.thunder, .parkbirds, .parkriver, .parkwind].contains(self) }
    var isAvailable: Bool { !isDownload || DownloadAsset.sound(self).flatMap(DownloadStore.fileURL) != nil }
    static var available: [SoundKind] { allCases.filter(\.isAvailable) }
    var isRecording: Bool { self != .pink && self != .brown && self != .white }

    var visualScene: SceneKind {
        switch self {
        case .rain, .thunder: return .rain
        case .ocean: return .ocean
        case .fire: return .ember
        case .stream, .birds, .wind, .parkbirds, .parkriver, .parkwind: return .prism
        case .crickets: return .stars
        case .waterfall: return .waterfall
        case .pink, .brown, .white: return .clouds
        }
    }

    /// 明确区分真实自然录音与有色噪音，不把合成噪音描述为实录。
    func subtitle(_ english: Bool) -> String {
        if isRecording { return english ? "Field recording · stereo loop" : "真实录音 · 立体声循环" }
        return english ? "Colored noise · smooth loop" : "有色噪音 · 平滑循环"
    }
}

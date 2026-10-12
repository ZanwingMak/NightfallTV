import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case black, aurora, stars, ocean, ember, dunes, prism, rain, clock, gallery
    var id: String { rawValue }

    /// 返回场景的中英文名称。
    func title(_ english: Bool) -> String {
        let names: [SceneKind: (String, String)] = [
            .black: ("纯黑 · 深眠", "Absolute black"), .aurora: ("极光之境", "Northern lights"),
            .stars: ("漫游星河", "Stellar drift"), .ocean: ("静海潮汐", "Ocean tides"),
            .ember: ("余烬炉火", "Quiet embers"), .dunes: ("沙漠落日", "Desert sunset"),
            .prism: ("林间树影", "Forest light"), .rain: ("雨落窗前", "Rain on glass"),
            .clock: ("时间缓行", "Slow hours"), .gallery: ("私人画廊", "Personal gallery")
        ]
        return english ? names[self]!.1 : names[self]!.0
    }

    /// 提供简短、真实的场景描述。
    func subtitle(_ english: Bool) -> String {
        let values: [SceneKind: (String, String)] = [
            .black: ("没有一点亮光，留音乐陪你入眠", "No glow. Just you and your music."),
            .aurora: ("拉普兰的真实极光，静静流动", "Real northern lights, filmed in Lapland."),
            .stars: ("真实夜空，星轨缓行", "A time-lapse of the real night sky."),
            .ocean: ("曼利海滩的潮汐，真实俯拍", "Waves filmed above Manly Beach."),
            .ember: ("一团暖光，一段安静的时间", "A little warmth for a quiet evening."),
            .dunes: ("莫哈韦沙漠，真实日落", "A real sunset over the Mojave Desert."),
            .prism: ("实拍林间光影，随风轻动", "Filmed sunlight moving through trees."),
            .rain: ("拉斯帕尔马斯，真实雨夜", "A rainy night filmed in Las Palmas."),
            .clock: ("低亮时钟，随时间缓慢漂移", "A dim clock that gently changes position."),
            .gallery: ("把你喜欢的照片，留在大屏上", "Your favorite photographs, beautifully framed.")
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
        }
    }

    var category: SceneCategory {
        switch self {
        case .black, .clock: return .night
        case .aurora, .stars, .ocean, .ember, .dunes, .prism, .rain: return .nature
        case .gallery: return .personal
        }
    }
}

enum SceneCategory: String, CaseIterable, Identifiable {
    case all, nature, night, personal
    var id: String { rawValue }
    /// 返回分类标题。
    func title(_ english: Bool) -> String {
        let values = [("全部", "All"), ("实拍", "Filmed"), ("夜间", "After dark"), ("照片", "Photos")]
        let pair = values[Self.allCases.firstIndex(of: self)!]
        return english ? pair.1 : pair.0
    }
}

enum SoundKind: String, CaseIterable, Codable, Identifiable {
    case rain, ocean, stream, fire, pink, brown
    var id: String { rawValue }
    /// 返回声景的本地化标题。
    func title(_ english: Bool) -> String {
        let values = [("细雨", "Soft rain"), ("潮汐", "Ocean tide"), ("溪流", "Forest stream"), ("炉火", "Fireplace"), ("粉噪音", "Pink noise"), ("棕噪音", "Brown noise")]
        let pair = values[Self.allCases.firstIndex(of: self)!]
        return english ? pair.1 : pair.0
    }
    var symbol: String {
        ["cloud.rain.fill", "water.waves", "drop.fill", "flame.fill", "waveform", "waveform.path"][Self.allCases.firstIndex(of: self)!]
    }
    var isRecording: Bool { self != .pink && self != .brown }

    /// 明确区分真实自然录音与有色噪音，不把合成噪音描述为实录。
    func subtitle(_ english: Bool) -> String {
        if isRecording { return english ? "Field recording · stereo loop" : "真实录音 · 立体声循环" }
        return english ? "Colored noise · smooth loop" : "有色噪音 · 平滑循环"
    }
}

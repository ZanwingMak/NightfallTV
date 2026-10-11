import Foundation

enum SceneKind: String, Codable, CaseIterable, Identifiable {
    case black, aurora, stars, ocean, ember, dunes, prism, rain, clock, gallery
    var id: String { rawValue }

    /// 返回场景的中英文名称。
    func title(_ english: Bool) -> String {
        let names: [SceneKind: (String, String)] = [
            .black: ("纯黑 · 深眠", "Absolute black"), .aurora: ("极光之境", "Northern lights"),
            .stars: ("漫游星河", "Stellar drift"), .ocean: ("月光海岸", "Moonlit tides"),
            .ember: ("余烬炉火", "Quiet embers"), .dunes: ("暮色沙丘", "Desert dusk"),
            .prism: ("流光之诗", "Chromatic flow"), .rain: ("雨落窗前", "Rain on glass"),
            .clock: ("时间缓行", "Slow hours"), .gallery: ("私人画廊", "Personal gallery")
        ]
        return english ? names[self]!.1 : names[self]!.0
    }

    /// 提供简短、真实的场景描述。
    func subtitle(_ english: Bool) -> String {
        let values: [SceneKind: (String, String)] = [
            .black: ("没有一点亮光，留音乐陪你入眠", "No glow. Just you and your music."),
            .aurora: ("越过群山，让夜空轻轻流动", "A ribbon of light above silent peaks."),
            .stars: ("在无垠的星光里，慢慢放空", "Lose yourself in a quiet universe."),
            .ocean: ("蓝色潮汐，温柔往复", "Silver ripples, an endless shore."),
            .ember: ("一团暖光，一段安静的时间", "A little warmth for a quiet evening."),
            .dunes: ("日落之后，沙海仍在呼吸", "Soft silhouettes beneath a fading sun."),
            .prism: ("让颜色像丝绸一样舒展", "Color unfolding like silk."),
            .rain: ("窗外下雨，室内安心", "Raindrops and distant city lights."),
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
        case .prism: return "circle.hexagongrid.fill"
        case .rain: return "cloud.rain.fill"
        case .clock: return "clock.fill"
        case .gallery: return "photo.on.rectangle.angled"
        }
    }

    var category: SceneCategory {
        switch self {
        case .black, .clock: return .night
        case .aurora, .stars, .ocean, .ember, .dunes, .rain: return .nature
        case .prism: return .art
        case .gallery: return .personal
        }
    }
}

enum SceneCategory: String, CaseIterable, Identifiable {
    case all, nature, art, night, personal
    var id: String { rawValue }
    /// 返回分类标题。
    func title(_ english: Bool) -> String {
        let values = [("全部", "All"), ("自然", "Nature"), ("生成艺术", "Generative art"), ("夜间", "After dark"), ("照片", "Photos")]
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
}

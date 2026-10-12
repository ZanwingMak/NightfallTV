import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHans = "zh-Hans", zhHant = "zh-Hant", en, ja, ko, fr, de, es, it, pt = "pt-BR", ru, ar, hi
    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return "Automatic"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        }
    }
    var resolved: AppLanguage { self == .system ? Self.device : self }
    var isRTL: Bool { resolved == .ar }
    var locale: Locale { Locale(identifier: resolved.rawValue) }

    /// 匹配系统语言及中文地区，未支持的语言稳定回退英语。
    static var device: AppLanguage { match(Locale.preferredLanguages.first ?? "en") }

    /// 为系统语言和测试提供同一份语言匹配规则。
    static func match(_ code: String) -> AppLanguage {
        if code.hasPrefix("zh") { return code.contains("Hant") || code.contains("TW") || code.contains("HK") ? .zhHant : .zhHans }
        if code.hasPrefix("pt") { return .pt }
        return allCases.first { $0 != .system && code.split(separator: "-").first == $0.rawValue.split(separator: "-").first } ?? .en
    }
}

enum Localizer {
    static let translations: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: String]].self, from: data)) ?? [:]
    }()
    private static let templates: [(String, NSRegularExpression)] = translations.keys.filter { $0.contains("{0}") }.compactMap { key in
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = escaped.replacingOccurrences(of: "\\{0\\}", with: "(.+?)").replacingOccurrences(of: "\\{1\\}", with: "(.+?)").replacingOccurrences(of: "\\{2\\}", with: "(.+?)")
        return (try? NSRegularExpression(pattern: "^" + pattern + "$", options: [.dotMatchesLineSeparators])).map { (key, $0) }
    }

    /// 从静态语言表翻译界面文本；带数量的文案保留运行时参数，用户内容不经过翻译。
    static func text(_ english: String, chinese: String? = nil, language: AppLanguage) -> String {
        let language = language.resolved
        if language == .en { return english }
        if language == .zhHans, let chinese { return chinese }
        if let value = translations[english]?[language.rawValue] { return value }
        for (key, expression) in templates {
            guard let match = expression.firstMatch(in: english, range: NSRange(english.startIndex..., in: english)),
                  var value = translations[key]?[language.rawValue] else { continue }
            for index in 1..<match.numberOfRanges {
                if let range = Range(match.range(at: index), in: english) { value = value.replacingOccurrences(of: "{\(index - 1)}", with: String(english[range])) }
            }
            return value
        }
        return english
    }
}

extension SceneKind {
    /// 将场景名称接入所有支持语言，保留旧偏好的中英文兼容方法。
    func title(_ language: AppLanguage) -> String { Localizer.text(title(true), chinese: title(false), language: language) }
    /// 将实拍描述接入本地化表。
    func subtitle(_ language: AppLanguage) -> String { Localizer.text(subtitle(true), chinese: subtitle(false), language: language) }
}
extension SceneCategory {
    /// 返回分类的本地化标题。
    func title(_ language: AppLanguage) -> String { Localizer.text(title(true), chinese: title(false), language: language) }
}
extension SoundKind {
    /// 返回声景的本地化名称。
    func title(_ language: AppLanguage) -> String { Localizer.text(title(true), chinese: title(false), language: language) }
    /// 明确区分实录与有色噪音，并本地化规格说明。
    func subtitle(_ language: AppLanguage) -> String { Localizer.text(subtitle(true), chinese: subtitle(false), language: language) }
}

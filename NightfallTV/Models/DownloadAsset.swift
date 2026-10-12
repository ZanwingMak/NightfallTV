import Foundation

struct DownloadAsset: Codable, Identifiable {
    let id: String
    let filename: String
    let bytes: Int64
    let sha256: String
    let url: URL
    let scene: SceneKind?
    let sound: SoundKind?
    let specification: String
    let sourceTitle: String
    let author: String
    let license: String
    let licenseURL: URL
    let sourceURL: URL
    let changes: String
    var size: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    var poster: SceneKind { scene ?? sound?.visualScene ?? .aurora }
    static let all: [DownloadAsset] = {
        guard let url = Bundle.main.url(forResource: "downloads", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DownloadAsset].self, from: data)) ?? []
    }()

    /// 使用实际场景或录音名称，不把可下载内容冒充内置内容。
    func title(_ language: AppLanguage) -> String { scene?.title(language) ?? sound?.title(language) ?? id }

    /// 按枚举对应固定清单，下载地址不会来自任意用户输入。
    static func scene(_ kind: SceneKind) -> DownloadAsset? { all.first { $0.scene == kind } }
    /// 查找录音对应的可选资源。
    static func sound(_ kind: SoundKind) -> DownloadAsset? { all.first { $0.sound == kind } }
}

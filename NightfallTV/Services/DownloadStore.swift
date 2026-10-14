import Foundation
import Combine
import CryptoKit

@MainActor
final class DownloadStore: ObservableObject {
    static let shared = DownloadStore()
    nonisolated static let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("NightfallMedia", isDirectory: true)
    @Published private(set) var ready: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var errors: Set<String> = []
    @Published private(set) var queued: [String] = []
    private var transfers: [String: MediaTransfer] = [:]
    private var generations: [String: UUID] = [:]

    /// 缓存允许系统清理；启动时只检查本地文件，不发起网络请求。
    init() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        for url in (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? [] where url.pathExtension == "partial" { try? FileManager.default.removeItem(at: url) }
        refresh()
    }

    /// 检查真实缓存存在与大小，系统清理后自动恢复为可下载状态。
    func refresh() { ready = Set(DownloadAsset.all.filter { Self.fileURL($0) != nil }.map(\.id)) }

    /// 用户选择的资源按顺序排队，去重并限制同时下载两项。
    func download(_ asset: DownloadAsset) {
        guard transfers[asset.id] == nil, !queued.contains(asset.id), Self.fileURL(asset) == nil,
              asset.url.scheme == "https", asset.url.host == "github.com", asset.bytes > 0 else { return }
        errors.remove(asset.id)
        queued.append(asset.id)
        startQueued()
    }

    /// 空出的传输槽自动接收下一项；未点击的内容不会进入队列。
    private func startQueued() {
        while transfers.count < 2, !queued.isEmpty {
            let id = queued.removeFirst()
            guard let asset = DownloadAsset.all.first(where: { $0.id == id }), Self.fileURL(asset) == nil else { continue }
            startTransfer(asset)
        }
    }

    /// 为每次实际传输建立独立代号，迟到的进度和完成回调不能污染重试。
    private func startTransfer(_ asset: DownloadAsset) {
        let generation = UUID()
        generations[asset.id] = generation
        errors.remove(asset.id)
        progress[asset.id] = 0
        let transfer = MediaTransfer(asset: asset, directory: Self.directory, progress: { [weak self] fraction in
            Task { @MainActor in
                guard self?.generations[asset.id] == generation else { return }
                self?.progress[asset.id] = fraction
            }
        }, completion: { [weak self] result in
            Task { @MainActor in
                guard let self, self.generations[asset.id] == generation else {
                    if case .success(let staging) = result { try? FileManager.default.removeItem(at: staging) }
                    return
                }
                self.transfers[asset.id] = nil
                self.progress[asset.id] = nil
                self.generations[asset.id] = nil
                do {
                    let staging = try result.get()
                    defer { try? FileManager.default.removeItem(at: staging) }
                    let destination = Self.directory.appendingPathComponent(asset.filename)
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: staging, to: destination)
                } catch { self.errors.insert(asset.id) }
                self.refresh()
                self.startQueued()
            }
        })
        transfers[asset.id] = transfer
        transfer.start()
    }

    /// 取消后不保留未验证文件，迟到的回调不能覆盖下一次下载。
    func cancel(_ asset: DownloadAsset) {
        queued.removeAll { $0 == asset.id }
        generations[asset.id] = nil
        transfers.removeValue(forKey: asset.id)?.cancel()
        progress[asset.id] = nil
        errors.remove(asset.id)
        startQueued()
    }

    /// 一次取消用户排队和传输中的全部内容，不删除已经下载好的资源。
    func cancelAll() {
        queued.removeAll()
        for id in Array(transfers.keys) {
            if let asset = DownloadAsset.all.first(where: { $0.id == id }) { cancel(asset) }
        }
    }

    var cachedBytes: Int64 { DownloadAsset.all.filter { ready.contains($0.id) }.reduce(0) { $0 + $1.bytes } }

    /// 删除用户选择的可下载缓存，内置内容保持可离线使用。
    func remove(_ asset: DownloadAsset) {
        cancel(asset)
        do { try FileManager.default.removeItem(at: Self.directory.appendingPathComponent(asset.filename)) }
        catch { errors.insert(asset.id) }
        refresh()
    }

    /// 返回完整验证过的资源路径；不存在或尺寸不符时禁止播放。
    nonisolated static func fileURL(_ asset: DownloadAsset) -> URL? {
        let url = directory.appendingPathComponent(asset.filename)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              (attributes[.size] as? NSNumber)?.int64Value == asset.bytes else { return nil }
        return url
    }

    /// 内置视频优先使用本地包；额外视频只读取已下载的缓存。
    nonisolated static func video(_ scene: SceneKind) -> URL? {
        Bundle.main.url(forResource: scene.rawValue, withExtension: "mp4") ?? DownloadAsset.scene(scene).flatMap(fileURL)
    }
    /// 录音使用同一下载状态，未下载时不会偷偷联网。
    nonisolated static func audio(_ sound: SoundKind) -> URL? {
        Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") ?? DownloadAsset.sound(sound).flatMap(fileURL)
    }
}

/// URLSession 在磁盘上接收资源，验证完整长度和 SHA-256 后才交给界面登记。
final class MediaTransfer: NSObject, URLSessionDownloadDelegate {
    private let asset: DownloadAsset
    private let directory: URL
    private let report: (Double) -> Void
    private let completion: (Result<URL, Error>) -> Void
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var result: Result<URL, Error>?

    /// 每次下载持有独立代理，旧任务不共享完成状态。
    init(asset: DownloadAsset, directory: URL, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        self.asset = asset; self.directory = directory; self.report = progress; self.completion = completion
    }
    /// 禁用响应缓存并设置有限超时，下载失败可由用户重试。
    func start() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 1800
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session?.downloadTask(with: asset.url)
        task?.resume()
    }
    /// 取消网络传输，由系统删除接收中的临时文件。
    func cancel() { task?.cancel() }
    /// 超过清单尺寸立即中止，防止错误响应填满电视缓存。
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > asset.bytes { downloadTask.cancel(); return }
        report(min(0.99, Double(totalBytesWritten) / Double(asset.bytes)))
    }
    /// 在串行后台代理队列校验文件，不在主线程载入大型媒体。
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200,
                  try Self.verify(location, bytes: asset.bytes, sha256: asset.sha256) else { throw CocoaError(.fileReadCorruptFile) }
            let staging = directory.appendingPathComponent(UUID().uuidString + ".partial")
            try FileManager.default.moveItem(at: location, to: staging)
            result = .success(staging)
        } catch { result = .failure(error) }
    }
    /// 只回调一次最终结果，并结束代理会话以释放引用。
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if case .success(let staging) = result { try? FileManager.default.removeItem(at: staging) }
            completion(.failure(error))
        } else { completion(result ?? .failure(CocoaError(.fileReadUnknown))) }
        session.finishTasksAndInvalidate()
        self.session = nil
        self.task = nil
    }
    /// 分块校验完整长度和摘要，拒绝截断文件及同尺寸错误内容。
    static func verify(_ url: URL, bytes: Int64, sha256: String) throws -> Bool {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.int64Value == bytes else { return false }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined() == sha256.lowercased()
    }
}

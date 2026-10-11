import UIKit
import ImageIO

actor PhotoLoader {
    static let shared = PhotoLoader()
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    /// 使用有超时与内存上限的独立缓存，不持久保存个人图片。
    init() {
        cache.totalCostLimit = 64 * 1024 * 1024
        cache.countLimit = 8
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    /// 流式限制下载到 12MB，并把高分辨率图片解码至最长 3840 像素。
    func load(_ address: String) async throws -> UIImage {
        guard Preferences.validPhotoURL(address), let url = URL(string: address) else { throw URLError(.badURL) }
        if let image = cache.object(forKey: address as NSString) { return image }
        let (bytes, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              response.url?.scheme == "https", response.mimeType?.hasPrefix("image/") == true,
              response.expectedContentLength <= 12 * 1024 * 1024 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 12 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3840,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: address as NSString, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}

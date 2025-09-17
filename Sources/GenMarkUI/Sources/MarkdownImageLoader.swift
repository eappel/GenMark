import Foundation
import SwiftUI
import UIKit

/// Protocol for loading markdown images. Consumers can provide their own implementation
/// by injecting it via the SwiftUI environment. All loaders operate on the main actor.
public protocol MarkdownImageLoader: AnyObject, Sendable {
    /// Loads an image for the given URL. Implementations must invoke the completion handler on the main actor.
    /// - Parameters:
    ///   - url: Image URL to load.
    ///   - sizeHint: Optional size hint supplied by the renderer (e.g. known dimensions from markdown attributes).
    ///   - completion: Completion handler invoked on the main actor with the resulting image (or nil on failure).
    func load(url: URL, sizeHint: CGSize?, completion: @escaping @MainActor (UIImage?) -> Void)
}

/// Default lightweight image loader backed by URLSession and NSCache.
public final class DefaultMarkdownImageLoader: NSObject, MarkdownImageLoader {
    public static let shared = DefaultMarkdownImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    override private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        super.init()
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // ~50 MB
    }

    public func load(url: URL, sizeHint: CGSize?, completion: @escaping @MainActor (UIImage?) -> Void) {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            Task { @MainActor in completion(cached) }
            return
        }

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await self.session.data(from: url)
                guard let image = UIImage(data: data)?.decoded() else {
                    await MainActor.run { completion(nil) }
                    return
                }
                let cost = data.count
                await MainActor.run {
                    self.cache.setObject(image, forKey: key, cost: cost)
                    completion(image)
                }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }
}

extension DefaultMarkdownImageLoader: @unchecked Sendable {}

private extension UIImage {
    /// Forces image decoding off the main thread to avoid layout hitching when the image is displayed
    /// while preserving the original orientation metadata.
    func decoded() -> UIImage {
        let size = self.size
        guard size.width > 0, size.height > 0 else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct MarkdownImageLoaderKey: EnvironmentKey {
    static let defaultValue: MarkdownImageLoader = DefaultMarkdownImageLoader.shared
}

public extension EnvironmentValues {
    var markdownImageLoader: MarkdownImageLoader {
        get { self[MarkdownImageLoaderKey.self] }
        set { self[MarkdownImageLoaderKey.self] = newValue }
    }
}

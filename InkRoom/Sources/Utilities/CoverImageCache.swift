import Foundation

/// 封面图片内存缓存，避免列表滚动时重复读盘。
///
/// `@unchecked Sendable`：底层 `NSCache` 本身线程安全，可跨 actor 安全共享。
final class CoverImageCache: @unchecked Sendable {
    static let shared = CoverImageCache()

    private let cache = NSCache<NSString, NSData>()

    private init() {
        // Dynamic limits based on device memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryMB = Int(physicalMemory / (1024 * 1024))
        
        // Use ~5% of physical memory for image cache, capped at 100MB
        let cacheLimitMB = min(max(memoryMB / 20, 20), 100)
        cache.countLimit = 150
        cache.totalCostLimit = cacheLimitMB * 1024 * 1024
    }

    func data(for path: String) -> Data? {
        cache.object(forKey: path as NSString) as Data?
    }

    func store(_ data: Data, for path: String) {
        cache.setObject(data as NSData, forKey: path as NSString, cost: data.count)
    }

    func remove(for path: String) {
        cache.removeObject(forKey: path as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

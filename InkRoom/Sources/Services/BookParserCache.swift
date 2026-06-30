import Foundation
import os

/// 线程安全的解析结果缓存，采用真正的 LRU（最近最少使用）淘汰策略。
///
/// 通过 `accessOrder` 维护访问顺序：每次读取/写入都将 key 移到队尾，
/// 淘汰时从队首删除。避免旧实现中 `Dictionary.first` 无序淘汰的问题。
///
/// 同步原语使用 `OSAllocatedUnfairLock`（iOS 16+/macOS 13+ 原生锁），
/// 而非 `DispatchQueue.sync`——后者在 Swift 并发上下文中会触发
/// `unsafeForcedSync` 运行时警告。`OSAllocatedUnfairLock` 是真锁，
/// 可从任意上下文（包括 actor 的 async 方法）安全调用。
///
/// `@unchecked Sendable`：所有可变状态都通过 `lock.withLock` 串行化保护，
/// 单例可跨 actor 安全共享。
final class BookParserCache: @unchecked Sendable {
    static let shared = BookParserCache()

    /// 锁保护的可变状态：缓存条目 + LRU 访问顺序 + 当前总大小。
    private struct State {
        var cache: [String: (book: ParsedBook, size: Int)] = [:]
        var accessOrder: [String] = []
        var currentCacheSizeBytes: Int = 0
    }

    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    // Cache limits to prevent memory pressure
    private let maxCacheEntries = 20
    private let maxCacheSizeBytes = 50 * 1024 * 1024 // 50 MB

    private init() {}

    // MARK: - Cache Operations

    func book(for path: String) -> ParsedBook? {
        lock.withLock { state in
            guard let entry = state.cache[path] else { return nil }
            touchAccessOrder(path, in: &state)
            return entry.book
        }
    }

    func set(_ book: ParsedBook, for path: String) {
        lock.withLock { state in
            let estimatedSize = book.chapters.reduce(0) { $0 + $1.content.count } + (book.coverImage?.count ?? 0)

            // 若已存在，先移除旧条目（更新大小与顺序）
            if let existing = state.cache.removeValue(forKey: path) {
                state.currentCacheSizeBytes -= existing.size
                state.accessOrder.removeAll { $0 == path }
            }

            // 淘汰直到容量与条目数都满足限制
            while !state.cache.isEmpty
                    && (state.cache.count >= maxCacheEntries
                        || state.currentCacheSizeBytes + estimatedSize > maxCacheSizeBytes) {
                evictLeastRecentlyUsed(in: &state)
            }

            state.cache[path] = (book, estimatedSize)
            state.accessOrder.append(path)
            state.currentCacheSizeBytes += estimatedSize
        }
    }

    func clear(for path: String? = nil) {
        lock.withLock { state in
            if let path = path {
                if let removed = state.cache.removeValue(forKey: path) {
                    state.currentCacheSizeBytes -= removed.size
                }
                state.accessOrder.removeAll { $0 == path }
            } else {
                state.cache.removeAll()
                state.accessOrder.removeAll()
                state.currentCacheSizeBytes = 0
            }
        }
    }

    // MARK: - Stats

    var entryCount: Int {
        lock.withLock { $0.cache.count }
    }

    var sizeInBytes: Int {
        lock.withLock { $0.currentCacheSizeBytes }
    }

    // MARK: - Private

    /// 将 key 移到访问顺序队尾（最近使用）。调用方须持有锁。
    private func touchAccessOrder(_ path: String, in state: inout State) {
        state.accessOrder.removeAll { $0 == path }
        state.accessOrder.append(path)
    }

    /// 淘汰队首（最久未使用）条目。调用方须持有锁。
    private func evictLeastRecentlyUsed(in state: inout State) {
        guard let oldest = state.accessOrder.first else { return }
        if let removed = state.cache.removeValue(forKey: oldest) {
            state.currentCacheSizeBytes -= removed.size
        }
        state.accessOrder.removeFirst()
    }
}

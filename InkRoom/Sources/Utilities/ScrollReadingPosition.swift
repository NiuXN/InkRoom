import CoreGraphics
import SwiftUI

struct ChapterFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

enum ScrollReadingPosition {
    /// 根据章节在滚动视图中的 frame，估算当前阅读页码。
    /// - Parameters:
    ///   - frames: 章节索引 -> frame 映射
    ///   - chapters: 章节列表
    ///   - anchorY: 视口锚点 Y 坐标（通常为安全区顶部 + 导航栏高度 + 一点偏移）
    static func estimatePage(
        frames: [Int: CGRect],
        chapters: [Chapter],
        anchorY: CGFloat = 120
    ) -> Int? {
        guard !chapters.isEmpty, !frames.isEmpty else { return nil }

        let sorted = frames.sorted { $0.value.minY < $1.value.minY }
        guard let visible = sorted.last(where: { $0.value.minY <= anchorY && $0.value.maxY > anchorY })
            ?? sorted.first(where: { $0.value.minY > anchorY })
            ?? sorted.first else {
            return nil
        }

        let index = visible.key
        guard index >= 0, index < chapters.count else { return nil }

        let chapter = chapters[index]
        let frame = visible.value
        guard frame.height > 0 else { return chapter.startPage }

        let pageSpan = max(1, chapter.endPage - chapter.startPage + 1)
        let progress = min(max((anchorY - frame.minY) / frame.height, 0), 1)
        let offset = Int(progress * Double(pageSpan - 1))
        return min(chapter.endPage, chapter.startPage + offset)
    }

    static func chapterIndex(for page: Int, in chapters: [Chapter]) -> Int {
        // Binary search since chapters are sorted by startPage
        var low = 0
        var high = chapters.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let chapter = chapters[mid]
            if page < chapter.startPage {
                high = mid - 1
            } else if page > chapter.endPage {
                low = mid + 1
            } else {
                return mid
            }
        }
        return max(0, min(low, chapters.count - 1))
    }
}
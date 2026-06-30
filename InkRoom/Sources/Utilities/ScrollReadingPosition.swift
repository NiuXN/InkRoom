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
        for (index, chapter) in chapters.enumerated() {
            if page >= chapter.startPage && page <= chapter.endPage {
                return index
            }
        }
        return 0
    }
}

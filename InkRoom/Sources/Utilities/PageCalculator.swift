import Foundation

/// 统一的页数计算与分页工具。
///
/// 采用"权重"模型：中文字符计 2，其他字符计 1，每 `charsPerPage` 个权重单位为一页。
/// 所有调用方（EPUB/TXT 解析、章节分页、阅读器取页内容）都应使用本工具，
/// 以保证 `ParsedBook.totalPages` 与各章节页数之和完全一致，避免目录跳转/翻页越界。
enum PageCalculator {
    /// 每页权重单位，与 `AppConfig.charsPerPage` 保持一致。
    static let charsPerPage = AppConfig.charsPerPage

    /// 判断一个 Unicode 标量是否属于中文基本区（用于权重计算）。
    @inline(__always)
    private static func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
    }

    /// 计算单段内容对应的页数（至少 1 页）。
    static func pageCount(for content: String) -> Int {
        guard !content.isEmpty else { return 1 }
        let weighted = content.unicodeScalars.reduce(0) { $0 + (isChinese($1) ? 2 : 1) }
        return max(1, weighted / charsPerPage)
    }

    /// 将内容按权重切分为页，返回每页文本（至少返回一页）。
    static func paginate(_ content: String) -> [String] {
        guard !content.isEmpty else { return [""] }

        var pages: [String] = []
        var current: [Unicode.Scalar] = []
        var weight = 0

        for scalar in content.unicodeScalars {
            current.append(scalar)
            weight += isChinese(scalar) ? 2 : 1
            if weight >= charsPerPage {
                pages.append(String(String.UnicodeScalarView(current)))
                current.removeAll(keepingCapacity: true)
                weight = 0
            }
        }
        if !current.isEmpty {
            pages.append(String(String.UnicodeScalarView(current)))
        }
        return pages
    }
}
